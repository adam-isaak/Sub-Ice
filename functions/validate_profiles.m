function [keep_prof] = validate_profiles(profiles, res, edge_elev, varargin)
% [keep_prof] = validate_profiles(profiles, edge_elev, keep_prof, frac_error)
% Returns a logical array of profiles to keep and which to remove based on
% set methods:
% - FractureThreshold, compares the edges to their average difference of 
%   adjacent with the channel base, those that fall below the threshold 
%   error percentage of the averaged depth are removed
% - MaxPeakTrough, compares the number of peaks and trough found using 
%   findPeak, if the number exceed the threshold values discard it
% - TroughThreshold, compares the average trough depth of the profile, and
%   if it falls below the percentage threshold beneath the channel base 
%   discard it
%
% required inputs:
% profiles = matrix containing profiles' sampled elevation [m]
% res = spatial resolution of the DEM [m]
% edge_elev = matrix containing each profiles left and right elevation [m]
%
% optional inputs
% validation_methods = methods to validate the profiles ("FractureThreshold", "MaxPeakTrough", or "TroughThreshold", "all" runs all the validation methods)
% frac_error = error threshold for fractures [%], the percentage below which a profile should excluded based on the average depth from edge the centre
% tr_min = percentage of elevation [%] below the channel that a profile will be excluded by if the average trough elevation falls below
% peak_prom = prominence of detecting excess peaks and troughs [m] (default: 2m)
% peak_w = width of the peak for detecting excess peaks and troughs [m] (default: 0, set to 0 it uses 3 times res)
% max_num_pk = max number of peaks before discarding [-] (default: 3)
% max_num_tr = max number of troughs before discarding [-] (default: 2)

%% input parser
% default parameter values
default_validation_methods = ["FractureThreshold"];
default_frac_error = 5;
default_tr_min = 5;
default_peak_prom = 2;
default_peak_w = 0;
default_max_num_pk = 3;
default_max_num_tr = 2;

% parse input arguments
p = inputParser; 
validValidationMethod = @(x) isempty(x) || ((isstring(x) && any(ismember(string(x), ["all", "FractureThreshold", "MaxPeakTrough", "TroughThreshold"]))));
validPercent = @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 100;
validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x >= 0);
addRequired(p, 'profiles');
addRequired(p, 'res');
addRequired(p, 'edge_elev');
addOptional(p, 'validation_methods', default_validation_methods, validValidationMethod)
addOptional(p, 'frac_error', default_frac_error, validPercent);
addOptional(p, 'tr_min', default_tr_min, validPercent);
addOptional(p, 'peak_prom', default_peak_prom, validScalarPosNum);
addOptional(p, 'peak_w', default_peak_w, validScalarPosNum);
addOptional(p, 'max_num_pk', default_max_num_pk, validScalarPosNum);
addOptional(p, 'max_num_tr', default_max_num_tr, validScalarPosNum);
parse(p, profiles, edge_elev, varargin{:}); 

validation_methods = p.Results.validation_methods;
frac_error = p.Results.frac_error;
tr_min = p.Results.tr_min;
peak_prom = p.Results.peak_prom;
peak_w = p.Results.peak_w;
max_num_pk = p.Results.max_num_pk;
max_num_tr = p.Results.max_num_tr;


%% actual function
% convert from percent to decimal point
frac_error = frac_error/100;
tr_min = tr_min/100;

% set the default peak width if unset
if peak_w == 0
    peak_w = 3*res;
end

% cast the validation methods to a string if they are empty
if isempty(validation_methods) 
    validation_methods = string(validation_methods);
end 

no_profs = size(profiles, 2);
prof_length = size(profiles, 1);
check = true(no_profs, 1);

% run through each profile and validate them based on all the criteria
for i = 1:no_profs
    % find the channel centre point elevation
    prof = profiles(:,i);
    pos = ceil(prof_length/2);
    channel_elev = prof(pos);

    % find the peaks and troughs to the specific thresholds
    pk_elev = findpeaks(prof, 'MinPeakProminence', peak_prom, 'MinPeakWidth', peak_w);
    tr_elev = findpeaks(-prof, 'MinPeakProminence', peak_prom, 'MinPeakWidth', peak_w);
    

    %% Maximum Peaks and Troughs
    % discards any profiles where the number of peaks and/or troughs exceed
    % the number of expected.
    if any(ismember(validation_methods, ["MaxPeakTrough", "all"]))
        if ((length(pk_elev) > max_num_pk) || (length(tr_elev) > max_num_tr)) && check(i)
            check(i) = false;
        end
    end

    %% Trough Threhold
    % check to see if the average elevation of the trough exceed the
    % threshold percentage of elevation below the channel elevation to
    % detect profiles that dip too much below the channel base
    if any(ismember(validation_methods, ["TroughThreshold", "all"]))
        avg_tr = mean(-tr_elev);
        if avg_tr < (channel_elev - channel_elev * tr_min) && check(i)
            check(i) = false;
        end 
    end 

    %% Fracture Threshold
    % checks if either side runs into a fracture by finding if the average 
    % difference between adjacent profiles for both the left and right 
    % edge and the channel base and seeing if they exceed it based on a set
    % error threshold
    if any(ismember(validation_methods, ["FractureThreshold", "all"]))
        % find the average elevation for the current profile and its
        % adjacent profiles
        if (i > 1 && i < no_profs)
            ledge_elev = mean(edge_elev((i-1):(i+1), 1));
            redge_elev = mean(edge_elev((i-1):(i+1), 2));
            cent_elev = mean(profiles(ceil(prof_length/2), (i-1):(i+1)));
        elseif (i == 1)        % average the first 3 for the initial profile
            ledge_elev = mean(edge_elev(1:3, 1));
            redge_elev = mean(edge_elev(1:3, 2));
            cent_elev = mean(profiles(ceil(prof_length/2), i:(i+1)));
        elseif (i == no_profs) % average the last 3 for the end profile
            ledge_elev = mean(edge_elev((no_profs-2):no_profs, 1));
            redge_elev = mean(edge_elev((no_profs-2):no_profs, 2));
            cent_elev = mean(profiles(ceil(prof_length/2), (no_profs-1):no_profs));
        end
    
        % set the edge threshold based on the error threshold set for fractures
        redge_error = (redge_elev - cent_elev) * frac_error;
        ledge_error = (ledge_elev - cent_elev) * frac_error;
    
        if ((edge_elev(i, 1) - channel_elev) < ledge_error  || (edge_elev(i, 2) - channel_elev) < redge_error) && check(i)
            check(i) = false;
        end
    end

end 

keep_prof = check;  % [-] Logical

disp('Validated each cross-section profiles for error.')
end