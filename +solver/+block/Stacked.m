classdef Stacked < solver.block.Block
    properties
        % LinearIndex  Linear index of endogenous quantities
        LinearIndex

        % Terminal  Rectangular simulation object for first-order terminal condition
        Terminal = simulate.Rectangular.empty(0)

        % MaxLab  Max lag of each quantity in this block
        MaxLag = double.empty(1, 0)    

        % MaxLead  Max lead of each quantity in this block
        MaxLead = double.empty(1, 0)   

        % FirstTime  First time (1..numOfColumnsToRun) to evaluate equations in for ith unknown (1..numOfQuantitiesInBlock*numOfColumnsToRun)
        FirstTime = double.empty(1, 0) 

        % LastTime  Last time (1..numOfColumnsToRun) to evaluate equations in for ith unknown (1..numOfQuantitiesInBlock*numOfColumnsToRun)
        LastTime = double.empty(1, 0)  

        % NumOfActiveEquations  Number of active equations
        NumOfActiveEquations
    end


    properties (Constant)
        VECTORIZE = true
    end


    methods
        function this = Stacked(varargin)
            this = this@solver.block.Block(varargin{:});
        end%
        
        
        function [exitStatus, error] = run(this, data, columnsToRun, ixLog)
            exitStatus = true;
            error = struct( );
            error.EvaluatesToNan = [ ];
            
            if isempty(this.PosQty)
                return
            end
            numOfQuantitiesInBlock = numel(this.PosQty);
            numOfEquationsInBlock = numel(this.PosEqn);
            numOfColumnsToRun = numel(columnsToRun);
            firstColumn = columnsToRun(1);
            lastColumn = columnsToRun(end);
            numColumns = lastColumn - firstColumn + 1;

            % Create linear index of unkowns in data
            linx = sub2ind( size(data.YXEPG), ...
                            repmat(this.PosQty(:), 1, numOfColumnsToRun), ...
                            repmat(firstColumn:lastColumn, numOfQuantitiesInBlock, 1) );
            linx = linx(:);

            % Create index of logs within linx
            linxLog = ixLog(this.PosQty);
            linxLog = repmat(linxLog(:), numOfColumnsToRun, 1);

            maxMaxLead = max(this.MaxLead);
            runFotc = this.Type==solver.block.Type.SOLVE && maxMaxLead>0;

            if this.Type==solver.block.Type.SOLVE
                % __Solve__
                % Initialize endogenous quantities
                z0 = data.YXEPG(linx);
                ixNan = isnan(z0);
                if any(ixNan)
                    z0(ixNan) = 1;
                end
                % Transform initial conditions for log variables before we check bounds;
                % bounds are in logs for log variables.
                anyLog = any(linxLog);
                if anyLog
                    z0(linxLog) = log( z0(linxLog) );
                end
                %* Make sure init conditions are within bounds.
                %* Empty bounds if all are Inf.
                %* Bounds are in logs for log variables.
                % checkBoundsOnInitCond( );
                % Test all equations in this block for NaNs and Infs.
                checkObjective = objective(z0);
                checkObjective = reshape(checkObjective, numOfEquationsInBlock, numOfColumnsToRun);
                indexInvalidData = ~isfinite(checkObjective);
                if any(indexInvalidData(:))
                    indexInvalidEquationsInBlock = any(indexInvalidData, 2);
                    error.EvaluatesToNan = this.PosEqn(indexInvalidEquationsInBlock);
                    return
                end
                [z, exitStatus] = solve(this, @objective, z0);
                writeEndogenousToData(z);
            else
                % __Assign__
                [z, exitStatus] = assign( );
            end
            
            exitStatus = all(isfinite(z)) && double(exitStatus)>0;
            return
            
            
            function [z, exitStatus] = assign( )
                isInvTransform = ~isempty(this.Type.InvTransform);
                for i = 1 : numOfColumnsToRun
                    z = this.EquationsFunc(data.YXEPG, columnsToRun(i), data.BarYX);
                    if isInvTransform
                        z = this.Type.InvTransform(z);
                    end
                    data.YXEPG(linx(i)) = z;
                end
                exitStatus = all(isfinite(data.YXEPG(linx)));
            end%
            
            
            function y = objective(z, ithJacob)
                if nargin<2
                    ithJacob = [ ];
                end
                writeEndogenousToData(z);
                
                if runFotc
                    % First-order terminal condition
                    flat(this.Terminal, data);
                end

                if isempty(ithJacob)
                    y = this.EquationsFunc(data.YXEPG, columnsToRun, data.BarYX);
                    y = y(:);
                else
                    firstColumnJacob = firstColumn + this.FirstTime(ithJacob) - 1;
                    lastColumnJacob = firstColumn + this.LastTime(ithJacob) - 1;
                    y = [ ];
                    for column = firstColumnJacob : lastColumnJacob
                        y = [y; this.NumericalJacobFunc{ithJacob}(data.YXEPG, column, data.BarYX)];
                    end
                end
            end%


            function writeEndogenousToData(z)
                z = real(z);
                if anyLog
                    z(linxLog) = exp(z(linxLog));
                end
                data.YXEPG(linx) = z;
            end%
                
        end%
    end
    
    
    methods       
        function prepareBlock(this, blz, opt)
            prepareBlock@solver.block.Block(this, blz, opt);
            % Remove auxiliary equations added to construct
            % exogenize/endogenize
            %{
            lastEquation = find(blz.InxEquations, 1, 'last');
            inxToRemove = this.PosEqn>lastEquation;
            this.PosEqn(inxToRemove) = [ ];
            % Create linear index to endogenous quantities
            numOfColumnsToRun = numel(blz.ColumnsToRun);
            numOfQuantitiesInBlock = numel(this.PosQty);
            linx = sub2ind( size(data.YXEPG), ...
                            repmat(this.PosQty(:), 1, numOfColumnsToRun), ...
                            repmat(blz.ColumnsToRun, numOfQuantitiesInBlock, 1) );
            this.LinearIndex = linx(:);

            % Create index of logs within linx
            linxLog = ixLog(this.PosQty);
            linxLog = repmat(linxLog(:), numOfColumnsToRun, 1);
            %}
        end%


        function createJacobPattern(this, blz)
            numOfQuantitiesInBlock = numel(this.PosQty);
            numOfEquationsInBlock = numel(this.PosEqn);
            numOfColumnsToRun = numel(blz.ColumnsToRun);
            numOfUnknownsInBlock = numOfQuantitiesInBlock * numOfColumnsToRun;
            % Incidence matrix numQuantities-by-numShifts
            acrossEquations = across(blz.Incidence, 'Equations');
            acrossEquations = acrossEquations(this.PosQty, :);
            % Incidence matrix numEquations-by-numQuantities
            acrossShifts = across(blz.Incidence, 'Shifts');
            acrossShifts = acrossShifts(this.PosEqn, this.PosQty);
            this.MaxLag = nan(1, numOfQuantitiesInBlock);
            this.MaxLead = nan(1, numOfQuantitiesInBlock);
            for i = 1 : numOfQuantitiesInBlock
                this.MaxLag(i) = find(acrossEquations(i, :), 1, 'first');
                this.MaxLead(i) = find(acrossEquations(i, :), 1, 'last');
            end
            sh0 = blz.Incidence.PosOfZeroShift;
            this.MaxLag = this.MaxLag - sh0;
            this.MaxLead = this.MaxLead - sh0;
            maxMaxLead = max(this.MaxLead);

            this.JacobPattern = false(numOfEquationsInBlock*numOfColumnsToRun, numOfQuantitiesInBlock*numOfColumnsToRun);
            this.FirstTime = nan(1, numOfQuantitiesInBlock*numOfColumnsToRun);
            this.LastTime = nan(1, numOfQuantitiesInBlock*numOfColumnsToRun);
            this.NumericalJacobFunc = cell(1, numOfUnknownsInBlock);
            this.NumOfActiveEquations = nan(1, numOfUnknownsInBlock);
            for t = 1 : numOfColumnsToRun
               for q = 1 : numOfQuantitiesInBlock
                    posUnknown = (t-1)*numOfQuantitiesInBlock + q;
                    pattern = false(numOfEquationsInBlock, numOfColumnsToRun);
                    firstTime = t - this.MaxLead(q);
                    if t-this.MaxLag(q)<=numOfColumnsToRun
                        % This value does not affect linear terminal
                        % condition.
                        lastTime = t - this.MaxLag(q);
                        if firstTime<1
                            firstTime = 1;
                        end
                        if lastTime>numOfColumnsToRun
                            lastTime = numOfColumnsToRun;
                        end
                        numTimes = lastTime - firstTime + 1;
                        inxOfActiveEquations = acrossShifts(:, q);
                        pattern(:, firstTime:lastTime) = repmat(inxOfActiveEquations, 1, numTimes);
                        if t==1
                            this.NumericalJacobFunc{posUnknown} = getNumericalJacobFunc( );
                        else
                            this.NumericalJacobFunc{posUnknown} = ...
                                this.NumericalJacobFunc{posUnknown-numOfQuantitiesInBlock};
                        end
                    else
                        % This value may affect linear terminal condition,
                        % so we have to differentiate all periods back to
                        % the max lead that can see the terminal condition.
                        firstTime = min(firstTime, numOfColumnsToRun-maxMaxLead);
                        if firstTime<1
                            firstTime = 1;
                        end
                        lastTime = numOfColumnsToRun;
                        pattern(:, firstTime:end) = true;
                        inxOfActiveEquations = true(numOfEquationsInBlock, 1);
                        this.NumericalJacobFunc{posUnknown} = getNumericalJacobFunc( );
                    end
                    this.NumOfActiveEquations(posUnknown) = sum(inxOfActiveEquations);
                    this.JacobPattern(:, posUnknown) = pattern(:);
                    this.FirstTime(posUnknown) = firstTime;
                    this.LastTime(posUnknown) = lastTime;
                end
            end

            return


            function f = getNumericalJacobFunc( )
                activeEquationsString = ['[', this.Equations{inxOfActiveEquations}, ']'];
                if this.VECTORIZE
                    %activeEquationsString = vectorize(activeEquationsString);
                end
                f = str2func([blz.PREAMBLE, activeEquationsString]);
            end%
        end%
    end
end
