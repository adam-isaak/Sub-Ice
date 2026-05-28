function [keep_prof] = validate_profiles(profiles, edge_elev, varargin)
% [keep_prof] = validate_profiles(profiles, edge_elev, keep_prof, frac_error)
% Returns a logical array of profiles to keep and which to remove based on
% criteria. Current criteria it removes for is:
% - Fractures, which it detects by comparing the edges to their average
%   difference with the channel base, those that fall below the threshold 
%   error percentage of the average depth are removed
%
% required inputs:
% profiles = matrix containing profiles' sampled elevation [m]
% edge_elev = matrix containing each profiles left and right elevation [m]
%
% optional inputs
% frac_error = percentage of the average profile below which should be excluded


%% input parser
% default parameter values
default_frac_error = 5;

% parse input arguments
p = inputParser; 
validPercent = @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 100;
addRequired(p, 'profiles');
addRequired(p, 'edge_elev');
addOptional(p, 'frac_error', default_frac_error, validPercent);
parse(p, profiles, edge_elev, varargin{:}); 

frac_error = p.Results.frac_error;


%% actual function
frac_error = frac_error/100;
no_profs = size(profiles, 2);
prof_length = size(profiles, 1);
keep_prof = false(no_profs, 1);

% finds the diffrence for the left and right between the edge
ledge_elev = mean(edge_elev(:, 1));
redge_elev = mean(edge_elev(:, 2));
cent_elev = mean(profiles(ceil(prof_length/2), :));
redge_error = (redge_elev - cent_elev) * frac_error;
ledge_error = (ledge_elev - cent_elev) *  frac_error;

% run through each profile and validate them based on all the criteria
for i = 1:no_profs

    % find the channel centre point elevation
    prof = profiles(:,i);
    pos = ceil(prof_length/2);
    channel_elev = prof(pos);

    % check if either side runs into a fracture
    keep_prof(i) = (edge_elev(i, 1) - channel_elev) > ledge_error  && (edge_elev(i, 2) - channel_elev) > redge_error;    
end 


end