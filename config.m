
%% Sub-Ice: DEM-based semi-automized mapping of ice shelf basal channels
%  Configuration file to be read by main scripts, for configuring filepaths
%  to input/output data, centerline search parameters and other user 
%  specifiable parameters. Update parameters as required! 
% 
%  (c) Dylan Kreynen
%  University of Oslo
%  2024-2026
% 
%  originally a project at the Int. Summer School in Glaciology
%  project team members: Marcelo Santis & Dylan Kreynen
%  advisor: Karen Alley (University of Manitoba)
%  McCarthy (AK), June 2024


%% user specifiable variables
%  (update as required)

% ice shelf DEM (should be GeoTIFF)
path_to_DEM = './input/thwaites/SETSM_WV02_20110127_15m.tif'; % to a single .tif for map_multi_channel.m, a directory of .tifs for map_channel_timeseries.m
DEM_nodata = -9999;         % DEM no data value
window_DEM = 0;             % window size for DEM smoothing [m] (will be rounded up to [pix], set to 0 for no smoothing)
                            % only works with map_multi_channel.m variations (TO DO: implement in map_channel_timeseries.m)

% output behaviour: 
results_dir = './output/';
proj_subdir = 'test/'; 
fig_subdir = 'fig/'; 
shp_subdir = 'shp/'; 
file_prefix = 'default_';   % (optional)
% output path will be constructed as follows: 
% results_dir/proj_subdir/fig_subdir/file_prefix_....ext

save_figs = 0;              % print figures to disk Y/N
figs_filetype = '-dpng';    % for use with "print()"
figs_resolution = '-r500';  % for use with "print()"
ext_figs = 1;               % plot (and print) extended figures Y/N
save_shps = 0;              % save output as shapefiles Y/N

% select method to specify channel start/end points
start_end_method = 2;
% 1 = click on start/end points
% 2 = read from shapefile
% 3 = manually enter in script
path_to_start_end_shp = './input/thwaites/points_20110127_15m.shp'; 
% ^ only needed when start_end_method is set to "2" (read from shapefile)
% important: only works if shapefile has same map projection as DEM! 
shelf_filter = ''; % no filtering: shelf_filter = ''; 
% ^ optional: filter shapefile on "Shelf" field

% centerline search parameters
search_step = 500;               % distance to step away from last known centerline point to construct search profile [m]
search_angle = 130;                % angle of view within to look for next centerline point [deg]
max_gradient = 2;                 % if new centerline point's elevation exceeds max. gradient, pick next best point instead [%]
window_cent = 100;                 % window size for search profile smoothing [m] (will be rounded up to [pix], set to 0 for no smoothing)
max_recursions = 1000;               % keep trying with slightly different search parameters in case channel end point is not found [-] (set to 0 or 1 for no recursion)
% length of search segment = (search_angle/360)*2*pi*search_step

% channel cross sectional profile parameters
prof_length   = 10000;            % length of cross sectional profiles [m]
prof_interval = 0;                % spacing between profiles along centerline [m]
                                  % (0 = one profile per centerline search segment)
% channel edge parameters
edge_method = "NearPeaks";        % method to use to identify channel edges ("SlopeThreshold", "KneePoint" or "NearPeaks")
min_width = [250, 250];                  % minimum channel width [m] (set to 0 for no minimum width)
max_width = [2000, 2000];                    % maximum channel width [m] (set to 0 for maximum width = prof_length)
sg_window = 1000;                 % window size for profile smoothing [m] (will be rounded up to [pix], set to 0 for no smoothing, Savitzky-Golay filter)
m_window = 10;                     % window size for edge smoothing [-] (no. of profile edges, set to 0 for no smoothing, median filter)

slope_thr = 0.00;                 % slope threshold for identifying edge [deg] (only used when edge_method = "SlopeThreshold")
peak_prom = 1;                  % MinPeakProm for findpeaks() [m], minimum prominence for channel edge (only used when edge_method = "NearPeaks")
keep_pks = 0;                     % prevent peaks from being adjusted by along-channel edge smoothing (0 or 1, only used when edge_method = "NearPeaks")

% profile validation parameters
validation_methods = ["all"];          % validation methods for the cross section ("EdgeThreshold", "MaxPeakTrough", or "AlongOutliers", set empty for no validation, set "all" to run all of them)

%% manage directories
%  (no need to update)

% add "functions" directory to search path
addpath("./functions")

% create output directories, if necessary
if save_figs % figures
    fig_dir = append(results_dir, proj_subdir, fig_subdir); 
    if ~exist(fig_dir, 'dir')
        mkdir(fig_dir)
    end
end

if save_shps % shapefiles
    shp_dir = append(results_dir, proj_subdir, shp_subdir); 
    if ~exist(shp_dir, 'dir')
        mkdir(shp_dir)
    end
end