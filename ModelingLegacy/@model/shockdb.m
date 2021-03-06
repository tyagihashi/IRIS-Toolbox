function [d, YXEPG] = shockdb(this, d, range, varargin)
% shockdb  Create model-specific databank with random shocks
%
% __Syntax__
%
% Input arguments marked with a `~` sign may be omitted
%
%     outputDatabank = shockdb(model, inputDatabank, range, ...)
%
%
% __Input Arguments__
%
% * `model` [ model ] - Model object.
%
% * `inputDatabank` [ struct | empty ] - Input databank to which shock time
% series will be added; if omitted or empty, a new databank will be
% created; if `inputDatabank` already contains shock time series, the data
% generated by `shockdb` will be added up with the existing data.
%
% * `range` [ numeric ] - Date range on which the shock time series will be
% generated and returned; if `inputDatabank` already contains shock time
% series going before or after `range`, these will be clipped down to
% `range` in the output databank.
%
%
% __Output Arguments__
%
% * `outputDabank` [ struct ] - Databank with newly generated shock time
% series added.
%
%
% __Options__
%
% * `NumOfDraws=@auto` [ numeric | @auto ] - Number of draws (i.e. columns)
% generated for each shock; if `@auto`, the number of draws is equal to the
% number of alternative parameterizations in the model `M`, or to the
% number of columns in shock series existing in the input databank,
% `InputData`.
%
% * `ShockFunc=@zeros` [ `@lhsnorm` | `@randn` | `@zeros` ] - Function used
% to generate random draws for new shock time series; if `@zeros`, the new
% shocks will simply be filled with zeros; the random numbers will be
% adjusted by the respective covariance matrix implied by the current model
% parameterization.
%
%
% __Description__
%
% Create a databank of time series for all model shocks.  The time series
% are generated using a specified function, `ShockFunc`.  The two typical
% cases are `ShockFunc=@zeros`, generating a zero time series for each
% shock, and `ShockFunc=@randn`, generating random shocks from a Normal
% distribution and scaled appropriately by the model shock covariance
% matrix.
% 
% If the input databank, `inputDatabank`, already contains some time series
% for some of the model shocks, the newly generated values will be added to
% these. All other databank entries will be preserved in the output
% databank unchanged.
%
%
% __Example__
%

% -IRIS Macroeconomic Modeling Toolbox
% -Copyright (c) 2007-2019 IRIS Solutions Team

TYPE = @int8;
TIME_SERIES_CONSTRUCTOR = iris.get('DefaultTimeSeriesConstructor');
TIME_SERIES_TEMPLATE = TIME_SERIES_CONSTRUCTOR( );

persistent parser
if isempty(parser)
    parser = extend.InputParser('model.shockdb');
    parser.addRequired('Model', @(x) isa(x, 'model'));
    parser.addRequired('InputDatabank', @(x) isempty(x) || isstruct(x));
    parser.addRequired('Range', @(x) DateWrapper.validateProperRangeInput(x));
    parser.addOptional('NumOfDrawsOptional', @auto, @(x) isequal(x, @auto) || (isnumeric(x) && isscalar(x) && x==round(x) && x>=1));
    parser.addParameter('NumOfDraws', @auto, @(x) isnumeric(x) && isscalar(x) && x==round(x) && x>=1);
    parser.addParameter('ShockFunc', @zeros, @(x) isa(x, 'function_handle'));
end
parser.parse(this, d, range, varargin{:});
numOfDrawsOptional = parser.Results.NumOfDrawsOptional;
opt = parser.Options;
if ~isequal(numOfDrawsOptional, @auto)
    opt.NumOfDraws = numOfDrawsOptional;
end

%--------------------------------------------------------------------------

numOfQuantities = numel(this.Quantity.Name);
indexOfShocks = this.Quantity.Type==TYPE(31) | this.Quantity.Type==TYPE(32);
ne = sum(indexOfShocks);
nv = length(this);
numOfPeriods = numel(range);
lsName = this.Quantity.Name(indexOfShocks);
lsLabel = this.Quantity.LabelOrName;
lsLabel = lsLabel(indexOfShocks);

if isempty(d) || isequal(d, struct( ))
    E = zeros(ne, numOfPeriods);
else
    E = datarequest('e', this, d, range);
end
numOfShocks = size(E, 3);

if isequal(opt.NumOfDraws, @auto)
    opt.NumOfDraws = max(nv, numOfShocks);
end
checkNumOfDraws( );

numOfLoops = max([nv, numOfShocks, opt.NumOfDraws]);
if numOfShocks==1 && numOfLoops>1
    E = repmat(E, 1, 1, numOfLoops);
end

if isequal(opt.ShockFunc, @lhsnorm)
    S = lhsnorm(sparse(1, ne*numOfPeriods), speye(ne*numOfPeriods), numOfLoops);
else
    S = opt.ShockFunc(numOfLoops, ne*numOfPeriods);
end

for ithLoop = 1 : numOfLoops
    if ithLoop<=nv
        Omg = covfun.stdcorr2cov(this.Variant.StdCorr(:, :, ithLoop), ne);
        F = covfun.factorise(Omg);
    end
    iS = S(ithLoop, :);
    iS = reshape(iS, ne, numOfPeriods);
    E(:, :, ithLoop) = E(:, :, ithLoop) + F*iS;
end

if nargout==1
    for i = 1 : ne
        name = lsName{i};
        e = permute(E(i, :, :), [2, 3, 1]);
        d.(name) = replace(TIME_SERIES_TEMPLATE, e, range(1), lsLabel{i});
    end
elseif nargout==2
    [minShift, maxShift] = getActualMinMaxShifts(this);
    numOfExtendedPeriods = numOfPeriods-minShift+maxShift;
    baseColumns = (1:numOfPeriods) - minShift;
    YXEPG = nan(numOfQuantities, numOfExtendedPeriods, numOfLoops);
    YXEPG(indexOfShocks, baseColumns, :) = E;
end

return


    function checkNumOfDraws( )
        if nv>1 && opt.NumOfDraws>1 && nv~=opt.NumOfDraws
            utils.error('model:shockdb', ...
                ['Input argument NDraw is not compatible with the number ', ...
                'of alternative parameterizations in the model object.']);
        end
        
        if numOfShocks>1 && opt.NumOfDraws>1 && numOfShocks~=opt.NumOfDraws
            utils.error('model:shockdb', ...
                ['Input argument NDraw is not compatible with the number ', ...
                'of alternative data sets in the input databank.']);
        end
        
        if numOfShocks>1 && nv>1 && nv~=numOfShocks
            utils.error('model:shockdb', ...
                ['The number of alternative data sets in the input databank ', ...
                'is not compatible with the number ', ...
                'of alternative parameterizations in the model object.']);
        end
    end%
end%

