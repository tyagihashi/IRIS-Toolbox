function [data, dates, this] = getData(this, timeRef, varargin)
% getData  Get data on specified range from TimeSubscriptable object
%
% Backend IRIS function
% No help provided

% -IRIS Macroeconomic Modeling Toolbox
% -Copyright (c) 2007-2019 IRIS Solutions Team

ERROR_INVALID_FREQUENCY = { 'TimeSeries:subsref:InvalidFrequency'
                            'Illegal date frequency in subscripted reference to %s object' };
testColon = @(x) (ischar(x) || isa(x, 'string')) && isequal(x, ':');

%--------------------------------------------------------------------------

% References to 2nd and higher dimensions
if ~isempty(varargin)
    this.Data = this.Data(:, varargin{:});
    if nargout>=3
        this.Comment = this.Comment(:, varargin{:});
        this = trim(this);
    end 
end

sizeOfData = size(this.Data);
serialOfStart = DateWrapper.getSerial(this.Start);
freqOfStart = DateWrapper.getFrequencyAsNumeric(this.Start);

if nargin<2 || testColon(timeRef) || isequal(timeRef, Inf)
    data = this.Data;
    dates = this.Range;
    return
end

missingValue = this.MissingValue;

if isempty(timeRef)
    data = repmat(missingValue, [0, sizeOfData(2:end)]);
    dates = DateWrapper.empty(0, 1);
    if nargout>2
        this = emptyData(this);
    end
    return
end

if isnumeric(timeRef) && ~isa(timeRef, 'DateWrapper') ...
   && all(round(timeRef)==timeRef)
    timeRef = DateWrapper(timeRef);
end

switch subsCase(this, timeRef)
    case {'NaD_[]', 'NaD_NaD', 'NaD_:'}
        data = repmat(missingValue, [0, sizeOfData(2:end)]);
        if nargout>1
            dates = startDateWhenEmpty(this);
            if nargout>2
                this = emptyData(this);
            end
        end
        return
    case {'Date_NaD', 'Empty_NaD'}
        data = repmat(missingValue, [0, sizeOfData(2:end)]);
        if nargout>1
            dates = startDateWhenEmpty(this);
            if nargout>2
                this = emptyData(this);
            end
        end
        return
    case 'NaD_Date'
        numOfPeriods = numel(timeRef);
        data = repmat(missingValue, [numOfPeriods, sizeOfData(2:end)]);
        if nargout>1
            dates = timeRef;
            if nargout>2
                this = emptyData(this);
            end
        end
        return
    case 'Date_Date'
        if nargout>2
            [data, ~, pos, this] = getDataNoFrills(this, timeRef);
        else
            [data, ~, pos] = getDataNoFrills(this, timeRef);
        end
        if numel(sizeOfData)>2
            data = reshape(data, [size(data, 1), sizeOfData(2:end)]);
        end
        if nargout>1
            serialOfDates = serialOfStart + pos - 1;
            dates = DateWrapper.getDateCodeFromSerial(freqOfStart, serialOfDates); 
            dates = dates(:);
            if isa(this.Start, 'DateWrapper')
                dates = DateWrapper(dates);
            end
        end
        return
end

end%


%
% Local Functions
%


function c = subsCase(this, timeRef)
    ERROR_INVALID_SUBSCRIPT = { 'TimeSubscriptable:subsCase:IllegalSubscript'
                                'Illegal subscripted reference or assignment to %s object' };
    testColon = @(x) (ischar(x) || isa(x, 'string')) && isequal(x, ':');

    %--------------------------------------------------------------------------

    start = this.Start;

    if isequaln(timeRef, NaN)
        ref = 'NaD';
    elseif isempty(timeRef)
        ref = '[]';
    elseif testColon(timeRef) || isequal(timeRef, Inf)
        ref = ':';
    elseif isnumeric(timeRef)
        ref = 'Date';
    else
        throw( exception.Base(ERROR_INVALID_SUBSCRIPT, 'error'), ...
               class(this) );
    end

    freq = DateWrapper.getFrequencyAsNumeric(start);
    if isnan(freq) || isempty(start)
        start = 'NaD';
    else
        start = 'Date';
    end

    c = [start, '_', ref];
end%

