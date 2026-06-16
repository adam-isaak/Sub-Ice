function [keep_prof] = validate_profiles(profiles, res, edge_elev, varargin)
% [keep_prof] = validate_profiles(profiles, edge_elev, keep_prof, frac_error)
% Returns a logical array of profiles to keep and which to remove based on
% set methods:
% - AlongOutliers, runs along the profile checking each point to see if the 
%   next point jumps above or below the last point threshold values
% - MaxPeakTrough, compares the number of peaks and trough found using 
%   findPeak, if the number exceed the threshold values discard it
% - EdgeThreshold, gets the average of each sides edge of adjacent 
%   profiles, and if the current profile either exceeds the the upper or
%   lower percentage threshold compared to the average
%
% required inputs:
% profiles = matrix containing profiles' sampled elevation [m]
% res = spatial resolution of the DEM [m]
% edge_elev = matrix containing each profiles left and right elevation [m]
%
% optional inputs
% validation_methods = methods to validate the profiles ("EdgeThreshold", "MaxPeakTrough", "AlongOutliers", "all" runs all the validation methods)
% uedge_error = error threshold percentage for sudden jumps in the edge compared to adjacent profiles [%] (default: 30%)
% dedge_error = error threshold percentage for sudden drops in the edge compared to adjacent profiles [%] (default: 30%)
% elev_min = height threshold any individual point can increase compared to the last point along a profile before rejection [m] (default: 5m)
% elev_max = height threshold any individual point can decrease compared to the last point along a profile before rejection [m] (default: 5m)
% peak_prom = prominence of detecting excess peaks and troughs [m] (default: 2m)
% peak_w = width of the peak for detecting excess peaks and troughs [m] (default: 0, set to 0 it uses the res [m])
% max_num_pk = max number of peaks before discarding [-] (default: 3)
% max_num_tr = max number of troughs before discarding [-] (default: 2)

%% input parser
% default parameter values
default_validation_methods = ["EdgeThreshold"];
default_uedge_error = 30;
default_dedge_error = 30;
default_elev_min = 5;
default_elev_max = 5;
default_peak_prom = 2;
default_peak_w = 0;
default_max_num_pk = 5;
default_max_num_tr = 3;

% parse input arguments
p = inputParser; 
validValidationMethod = @(x) isempty(x) || ((isstring(x) && any(ismember(string(x), ["all", "EdgeThreshold", "MaxPeakTrough", "AlongOutliers"]))));
validPercent = @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 100;
validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x >= 0);
addRequired(p, 'profiles');
addRequired(p, 'res');
addRequired(p, 'edge_elev');
addOptional(p, 'validation_methods', default_validation_methods, validValidationMethod)
addOptional(p, 'uedge_error', default_uedge_error, validPercent);
addOptional(p, 'dedge_error', default_dedge_error, validPercent);
addOptional(p, 'elev_min', default_elev_min, validScalarPosNum);
addOptional(p, 'elev_max', default_elev_max, validScalarPosNum);
addOptional(p, 'peak_prom', default_peak_prom, validScalarPosNum);
addOptional(p, 'peak_w', default_peak_w, validScalarPosNum);
addOptional(p, 'max_num_pk', default_max_num_pk, validScalarPosNum);
addOptional(p, 'max_num_tr', default_max_num_tr, validScalarPosNum);
parse(p, profiles, edge_elev, varargin{:}); 

validation_methods = p.Results.validation_methods;
uedge_error = p.Results.uedge_error;
dedge_error = p.Results.dedge_error;
elev_min = p.Results.elev_min;
elev_max = p.Results.elev_max;
peak_prom = p.Results.peak_prom;
peak_w = p.Results.peak_w;
max_num_pk = p.Results.max_num_pk;
max_num_tr = p.Results.max_num_tr;


%% actual function
% convert from percent to decimal point
uedge_error = uedge_error/100;
dedge_error = dedge_error/100;

% set the default peak width if unset
if peak_w == 0
    peak_w = res;
end

% cast the validation methods to a string if they are empty
if isempty(validation_methods) 
    validation_methods = string(validation_methods);
end 

no_profs = size(profiles, 2);
prof_length = size(profiles, 1);
check = true(no_profs, 1);
scan_area = 2;
scan_start = 1 + 2*scan_area;
scan_end = no_profs - 2*scan_area;

% run through each profile and validate them based on all the criteria
for i = 1:no_profs
    % find the channel centre point elevation
    prof = profiles(:,i)';

    %% Maximum Peaks and Troughs
    % discards any profiles where the number of peaks and/or troughs exceed
    % the number of expected.
    if any(ismember(validation_methods, ["MaxPeakTrough", "all"]))
        % find the peaks and troughs to the specific thresholds
        pk_elev = findpeaks(prof, 'MinPeakProminence', peak_prom, 'MinPeakWidth', peak_w);
        tr_elev = findpeaks(-prof, 'MinPeakProminence', peak_prom, 'MinPeakWidth', peak_w);

        if ((length(pk_elev) > max_num_pk) || (length(tr_elev) > max_num_tr)) && check(i)
            check(i) = false;
        end
    end

    %% AlongOutliers
    % runs along the profile and checks to see if there are any jumps above
    % or below the set thresholds, and if there are any sudden jumps 
    % exclude that profile due to likely presence of outlier data  
    if any(ismember(validation_methods, ["AlongOutliers", "all"]))
        c = 1;
        while check(i) && c < prof_length;
            % increment the position
            c = c+1;

            if prof(c-1) > (prof(c) + elev_max) || prof(c-1) < (prof(c) - elev_min)
               check(i) = false;
            end 
        end
    end
   

    %% Edge Threshold
    % checks to see if any profiles edge suddenly drops or jumps compared
    % to it's adjacent profiles indicating falling into a fracture or ice 
    % rumple that should be excluded from the profiles
    if any(ismember(validation_methods, ["EdgeThreshold", "all"]))
        % find the average elevation for edge of the current profile and 
        % it's adjacent profiles within the scan area
        if (i > scan_area && i < no_profs - scan_area)
            ledge_elev = mean(edge_elev((i-scan_area):(i+scan_area), 1));
            redge_elev = mean(edge_elev((i-scan_area):(i+scan_area), 2));
        elseif (i <= scan_area)        % average the first 3 for the initial profile
            ledge_elev = mean(edge_elev(1:scan_start, 1));
            redge_elev = mean(edge_elev(1:scan_start, 2));
        elseif (i >= no_profs - scan_area) % average the last 3 for the end profile
            ledge_elev = mean(edge_elev(scan_end:no_profs, 1));
            redge_elev = mean(edge_elev(scan_end:no_profs, 2));
        end
    
        % check if the edge dips suddenly compared to adjacent profiles
        redge_error = redge_elev - redge_elev * dedge_error;
        ledge_error = ledge_elev - ledge_elev * dedge_error;
    
        if (edge_elev(i, 1) < ledge_error || edge_elev(i, 2) < redge_error) && check(i)
            check(i) = false;
        end
        
        % check if the edge rises suddenly compared to adjacent profiles 
        redge_error = redge_elev + redge_elev * uedge_error;
        ledge_error = ledge_elev + ledge_elev * uedge_error;

        if edge_elev(i, 1) > ledge_error  || (edge_elev(i, 2) > redge_error) && check(i)
            check(i) = false;
        end
    end

end 

keep_prof = check;  % [-] Logical
if any(~keep_prof)
    disp(' -- Profile(s) excluded based on validation methods and criteria.')
end

disp('Validated each cross-section profiles for error.')
end