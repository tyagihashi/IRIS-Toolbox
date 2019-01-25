function Def = irisoptim( )
% irisoptim  [Not a public function] Default options for irisoptim package.
%
% Backend IRIS function.
% No help provided.

% -IRIS Macroeconomic Modeling Toolbox.
% -Copyright (c) 2007-2019 IRIS Solutions Team.

%--------------------------------------------------------------------------

Def = struct( );

Def.pso = { ...
    'CognitiveAttraction', 0.5, @(x) isnumericscalar(x) && x>=0 && x<=1, ...
    'ConstrBoundary','reflect', @(x) isanystri(x,{'soft','reflect','absorb'}), ...
    'Display','iter', @(x) isanystri(x,{'off','iter','final'}), ...
    'DemoMode','off', @(x) isanystri(x,{'off','fast','pretty','on'}), ...
    'FitnessLimit', -Inf, @(x) isnumericscalar(x), ...
    'Generations,maxit,maxiter', 1000, @(x) isnumericscalar(x) && x>0, ...
    'HybridFcn,hybrid', false, @(x) islogicalscalar(x) || isfunc(x) ...
        || iscell(x) || ischar(x), ...
    'IncludeInitialValue', false, @(x) islogical(x), ...
    'InitialPopulation', [ ], @(x) isnumeric(x), ...
    'InitialPopulationUsesBounds', false, @(x) islogical(x), ...
    'InitialVelocities', [ ], @(x) isnumeric(x), ...
    'KnownMin', [ ], @(x) isnumericscalar(x) || isempty(x), ...
    'PlotFcns', { }, @(x) iscell(x) && all(cellfun('isclass', x, 'function_handle')), ...
    'PlotInterval', 1, @(x) isintscalar(x) && x>0, ...
    'PopInitRange', [ ], @(x) isnumeric(x) || isempty(x), ...
    'PopulationSize', 40, @(x) isintscalar(x) && x>0, ...
    'SocialAttraction', 1.25, @(x) isnumericscalar(x), ...
    'StallGenLimit,stall', 50, @(x) isintscalar(x) && x>0, ...
    'TimeLimit', Inf, @(x) isnumericscalar(x,0), ...
    'TolCon', 1e-6, @(x) isnumericscalar(x,0), ...
    'TolFun', 1e-6, @(x) isnumericscalar(x,0), ...
    'VelocityLimit', Inf, @(x) isnumericscalar(x,0), ...
    'UpdateInterval', 0, @(x) isnumericscalar(x), ...
    'UseParallel,parallel', false, @islogicalscalar, ...
    } ;

Def.irismin = { ...
    'diffMin', sqrt(eps), @(x) isnumericscalar(x,0), ...
    'diffMax', 0.1, @(x) isnumericscalar(x,0), ...
    'diffMethod,diff', 'forward', @(x) isanystri(x,{'forward','central'}), ...
    'wolfeParams,wolfe', [1e-4,.9], @(x) isnumeric(x) && numel(x)==2 && x(1)<x(2), ...
    'updateMethod,update', 'damped-bfgs', @(x) isanystri(x, {'damped-bfgs','bfgs','dfp','sr1','psb'}) || isequal(x,@auto), ...
    'display', 'iter', @(x) isanystri(x,{'off','iter','final'}), ...
    'hessian', 'identity', @(x) isanystri(x,'identity') || isnumeric(x) && det(x)>0, ...
    'linesearchMethod,linesearch', 'interp', @(x) isanystri(x,{'interp','backtracking','backtrack','none'}), ...
    'maxfunevals,maxfuneval', 1e+6, @(x) isnumericscalar(x,0), ...
    'maxit,maxiter', 1e+5, @(x) isnumericscalar(x), ...
    'stepMethod,step', 'trust-region', @(x) isanystri(x,{'linesearch','trust-region'}), ...
    'strong', false, @(x) islogical(x), ...
    'tolx', sqrt(eps), @(x) isnumericscalar(x+eps,0), ...
    'tolfun', 1e-6, @(x) isnumericscalar(x+eps,0), ...
    'trustregionMethod,trustregion', 'dogleg', @(x) isanystri(x,{'dogleg','steihaug'}), ...
    'updateInterval', 0, @(x) isnumericscalar(x), ...
    } ;

Def.brent = { ...
    'tol', sqrt(eps), @(x) isnumericscalar(x,0), ...
    'maxit', 1e+3, @(x) isnumericscalar(x,0), ...
    'display', 'iter', @(x) isanystri(x,{'off','iter','final'}), ...
    } ;

% alps
isint = @(x,varargin) isnumericscalar(x,varargin{:}) && floor(x)==x ;

Def.alps = {...
    'display', 'iter', ...
        @(x) isanystri(x,{'off','iter','final','debug'}), ...
    'parallel', false, @islogical, ...
    'layerSize,populationSize', 100, isint, ...
    'layers,nlayer', 10, isint, ...
    'maxit,maxiter,generations', 1e+5, isint, ...
    'ageGap', 20, @(x) isint(x,1), ...
    'nparents', @auto, @(x) isint(x,0) || ( isfunc(x) && eq(x,@auto) ), ...
    'hybrid', false, @(x) islogical(x) ...
        || ( iscell(x) && isfunc(x{1}) ) ...
        || ( ischar(x) && isanystri(x,{'fmincon','irismin'}) ), ...
    'includeInitialValue', false, @(x) islogical(x), ...
    'mutationType', 'cauchy', ...
        @(x) isanystri(x,{'none','flipbit','gaussian','cauchy'}), ...
    'mutationParam', @(x) exp(-x), @(x) isnumericscalar(x) || isfunc(x), ...
    'selectionType', 'tournament', ...
        @(x) isanystri(x,{'universal','tournament','propotionate',...
        'truncation','roulette','rank'}), ...
    'selectionParam', 0.2, @(x) isnumeric(x), ...
    'crossoverType,crossover', 'uniform', ...
        @(x) isanystri(x,{'hill','uniform','one-point','two-point'}), ...
    'initType', 'uniform', @(x) isanystri(x,{'uniform'}) || isfunc(x), ...
    'elite', 3, @(x) islogical(x) || isint(x,0) || isfunc(x), ...
    'ageSeparation', 'polynomial', ...
        @(x) isanystri(x,{'linear','polynomial','exponential'}), ...
    'agingMethod', 'generations', ...
        @(x) isanystri(x,{'funevals','generations'}), ...
    'adaptive', false, @islogical, ...
    'stall,StallGenLimit', 1000, @(x) isint(x,0), ...
    'useInertia', false, @(x) islogical(x), ...
    'prior', [ ], @(x) isstruct(x), ...
    'plot', { }, @(x) iscell(x) || isfunc(x) || ( ischar(x) && any(strcmpi(x,{'plotfitness'})) ), ...
    } ;

Def.testfn = { ...
    'ub', [ ], @isnumeric, ...
    'lb', [ ], @isnumeric, ...
    'x0', [ ], @isnumeric, ...
    'type', '', @ischar, ...
    'notes', '', @ischar, ...
    } ;

end


