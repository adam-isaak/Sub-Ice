%% Sub-Ice: DEM-based semi-automized mapping of ice shelf basal channels
%  Algorithm that returns ice shelf basal channels' centerline, outlines
%  and cross sectional profiles; based on surface expressions in a DEM. 
%  This script maps one or more channels given a single DEM and user
%  identified channel start and end points. (See "map_channel_timeseries.m"
%  for mapping a single channel over different DEMs.)
% 
%  Input: 
%   - DEM (GeoTIFF) 
%   - channel start and end points (through GUI or read from shapefile)
% 
%  Output: 
%   - channel centerlines and outlines (figures and georeferenced shapefiles)
%   - cross sectional elevation/depth profiles (figures)
%   - channel depth and width along centerlines (figures)
% 
%  (c) Dylan Kreynen
%  University of Oslo
%  2024-2026
% 
%  originally a project at the Int. Summer School in Glaciology
%  project team members: Marcelo Santis & Dylan Kreynen
%  advisor: Karen Alley (University of Manitoba)
%  McCarthy (AK), June 2024


%% read DEM from GeoTIFF
%  and smooth if required

if path_to_DEM(end-3:end) ~= ".tif"
    error("path_to_DEM should point to a single DEM .tif file (check in config.m). ")
end

% read from geotiff
[DEM, R] = readgeoraster(path_to_DEM);
res = R.CellExtentInWorldX;     % resolution of DEM [m]

% replace no data with NaN
DEM(DEM==DEM_nodata) = NaN; 

% check if smoothed version of DEM exists
% if it exists: load
% if not: smooth DEM (and save)
if window_DEM ~= 0
    % smoothing requested by user
    fn_smooth = append(path_to_DEM(1:end-4), '_smooth_', string(window_DEM)', '.mat'); 
    window = ceil(window_DEM/res);  % from [m] to [pix]
    try 
        DEM_smooth = load(fn_smooth).DEM_smooth; 
        disp(append("Loaded smoothed version of DEM from disk: ", fn_smooth, " Window size: ", string(window_DEM), " [m] (ca. ", string(window), " [pix]). "))
    catch
        disp(append("Could not find smoothed version of DEM. Smoothing now. Window size: ", string(window_DEM), " [m] (ca. ", string(window), " [pix]). "))
        DEM_smooth = smoothdata2(DEM, 'movmean', window, 'omitnan'); 
        save(fn_smooth, 'DEM_smooth'); 
    end
   
    % test: check if DEM dimensions agree
    if size(DEM) ~= size(DEM_smooth)
        error("Dimensions of DEM and smoothed version do not agree. ")
    end

else
    % no smoothing requested
    DEM_smooth = DEM; 
    disp("Loaded DEM, no smoothing requested. ")
end


%% specify channel centerline start/end points
%  have user click on channel start and end points through GUI, read start
%  and end points from shapefile or enter img coordinates manually

figure(config_num*100000)
imagesc(DEM, clims)
hold on
axis image
colormap gray
xlabel('x coord [pix]')
ylabel('y coord [pix]')
text_offs = 3;  % [pix]

if start_end_method == 1 
    % click on start/end points 
    c = 0; 
    while true
        c = c+1; 
        title(append("Left click on channel start and end points. Right click when done! "))
        disp(append("Left click on channel start and end points. Right click when done! "))
        
        % start point
        [P_start(c,1), P_start(c,2), button] = ginput(1);
        if button == 3                  % right click
            c = c-1; 
            P_start = P_start(1:c, :);  % keep valid entries only
            break
        end
        scatter(P_start(c,1), P_start(c,2), 'm', 'filled')
        text(P_start(c,1) + text_offs, P_start(c,2) + text_offs, 'start', 'Color', 'm')        
        
        % end point
        [P_end(c,1), P_end(c,2), button] = ginput(1); 
        if button == 3
            c = c-1; 
            P_start = P_start(1:c, :);
            P_end = P_end(1:c, :);
            break
        end
        text(P_end(c,1) + text_offs, P_end(c,2) + text_offs, 'end', 'Color', 'm')
        scatter(P_end(c,1), P_end(c,2), 'm', 'filled')
    end
    
    no_channels = c; 
    disp(append("Entered ", string(no_channels), " channels' start and end points. "))
    channel_label = strings(no_channels);
    for c = 1:no_channels
        channel_label(c) = string(input(append("Provide a label for channel ", string(c), ': '), 's'));
    end
    
    
elseif start_end_method == 2
    % read start/end points from shapefile
    % only works if shapefile has same map projection as DEM!
    S = shaperead(path_to_start_end_shp); 
    % filter on "shelf" field
    if ~isempty(shelf_filter)
        S = S(strcmp({S.Shelf}, shelf_filter));
    end
    [x_startend, y_startend] =  worldToIntrinsic(R, vertcat(S.X), vertcat(S.Y));
    
    % assumption: points are ordered, start channel 1, end channel 1, ... 
    % > shapefile should have even amount of points
    if rem(length(x_startend), 2) == 0
        idx = 1:length(x_startend); 
        even_idx = rem(idx, 2) == 0; 
        P_start = [x_startend(~even_idx), y_startend(~even_idx)]; 
        P_end = [x_startend(even_idx), y_startend(even_idx)]; 
    else
        error('Found odd number of start and end points in shapefile. Please provide an even number of points, ordered channel start, end respectively. '); 
    end 

    scatter(P_start(:,1), P_start(:,2), 'm', 'filled')
    scatter(P_end(:,1), P_end(:,2), 'm', 'filled')
    text(P_start(:,1) + text_offs, P_start(:,2) + text_offs, 'start', 'Color', 'm')
    text(P_end(:,1) + text_offs, P_end(:,2) + text_offs, 'end', 'Color', 'm')

    no_channels = size(P_start, 1); 
    disp(append("Found ", string(no_channels), " channels' start and end points in shapefile. "))
    
    % channel label - feel free to adjust: 
    channel_label = append("channel-", string(1:no_channels)); 
    % (should be string)
    
    
elseif start_end_method == 3
    % enter start/end points manually below
    P_start = [353, 128];    % x, y in image coord [pix]
    P_end = [260, 84];       % x, y in image coord [pix]
    scatter(P_start(:,1), P_start(:,2), 'm', 'filled')
    scatter(P_end(:,1), P_end(:,2), 'm', 'filled')
    text(P_start(:,1) + text_offs, P_start(:,2) + text_offs, 'start', 'Color', 'm')
    text(P_end(:,1) + text_offs, P_end(:,2) + text_offs, 'end', 'Color', 'm')
    
else
    error('Specify a valid method to enter channel start/end points (under "user specifiable variables" in config.m). ')
end


%% map channel geometries and extract profiles
%  and visualize on overview figure

figure(config_num*100000)
hold off
imagesc(DEM, clims)
axis image
colormap gray
title('mapped channel geometries (overview)')
xlabel('x coord [pix]')
ylabel('y coord [pix]')
hold on

x_cent = cell(no_channels, 1);  
y_cent = cell(no_channels, 1); 
channel_length = cell(no_channels, 1); 
profiles = cell(no_channels, 1); 
x_prof = cell(no_channels, 1); 
y_prof = cell(no_channels, 1); 
edge_idx = cell(no_channels, 1); 
edge_coord = cell(no_channels, 1); 
edge_elev = cell(no_channels, 1); 
fchannel = cell(no_channels, 1);
trough_elev = cell(no_channels, 1); 
trough_depth = cell(no_channels, 1);
keep_prof = cell(no_channels, 1);

% to store whether we "successfully" found the channel centerline: 
channel_status = zeros(no_channels, 1); 

% loop over channels
for c = 1:no_channels
    disp(append("Start mapping channel geometry of ", channel_label(c), ". ")) 
    
    % find centerline
    % attention: possibly using smoothed DEM to find centerlines! 
    [x_cent{c}, y_cent{c}, cent_length] = find_centerline(P_start(c,:), P_end(c,:), DEM_smooth, R, ... 
                                                'search_step',      search_step, ... 
                                                'search_angle',     search_angle, ... 
                                                'max_gradient',     max_gradient, ... 
                                                'window',           window_cent, ...
                                                'max_recursions',   max_recursions); 
    channel_length{c} = sum(cent_length);       % in [pix]
    channel_length{c} = channel_length{c}*res;  % in [m]

    if ~isnan(channel_length{c})
        % found channel end
        channel_status(c) = 1;
    end

    % find cross sectional profiles
    [profiles{c}, x_prof{c}, y_prof{c}] = find_profiles(x_cent{c}, y_cent{c}, DEM, R, ...
                                                'prof_length',      prof_length, ...
                                                'prof_interval',    prof_interval);
    no_profiles = size(profiles{c}, 2); 

    % find channel edges/outlines
    [edge_idx{c}, edge_coord{c}, edge_elev{c}] = find_edges(profiles{c}, x_prof{c}, y_prof{c}, res, ...
                                                'edge_method',      edge_method, ...
                                                'knee_method',      knee_method, ...
                                                'min_width',        min_width, ...
                                                'max_width',        max_width, ...
                                                'sg_window',        sg_window, ...
                                                'm_window',         m_window, ...
                                                'slope_thr',        slope_thr, ...
                                                'peak_prom',        peak_prom, ...
                                                'z_thr_elev',       z_thr_elev, ...
                                                'z_thr_idx',        z_thr_idx, ...
                                                'edge_subst_window', edge_subst_window);

    % find channel trough elevation and depth
    [trough_elev{c}, trough_depth{c}] = find_trough(profiles{c}, edge_elev{c}, ...
                                                'z_thr',            z_thr_trough_elev, ...
                                                'subst_window',     trough_subst_window); 

    channel_width = (edge_idx{c}(:,1)-edge_idx{c}(:,2))*res; % [m]

   
    % validate all cross sections
    [keep_prof{c}] = validate_profiles(profiles{c}, res, edge_elev{c}, ... 
                                                'validation_methods', validation_methods);

    % visualize
    % profile transects
    hold on
    if plot_prof_transects == 1
        scatter(x_prof{c}(:, keep_prof{c}), y_prof{c}(:, keep_prof{c}), 1, 'w')
        scatter(x_prof{c}(:, ~keep_prof{c}), y_prof{c}(:, ~keep_prof{c}), 2, 'b')
    end

    % centerlines
    scatter(x_cent{c}, y_cent{c}, 15, 'r', 'filled')
    plot(x_cent{c}, y_cent{c}, 'r')
    
    % edges/outlines
    scatter(edge_coord{c}(:,1), edge_coord{c}(:,2), 15, 'g', 'filled')
    scatter(edge_coord{c}(:,3), edge_coord{c}(:,4), 15, 'g', 'filled')
    if plot_edge_gaps == 1
        lvalid = ~isnan(edge_coord{c}(:,1));
        rvalid = ~isnan(edge_coord{c}(:,3));
        plot(edge_coord{c}(lvalid,1), edge_coord{c}(lvalid,2), 'g')
        plot(edge_coord{c}(rvalid,3), edge_coord{c}(rvalid,4), 'g')
    else
        plot(edge_coord{c}(:,1), edge_coord{c}(:,2), 'g')
        plot(edge_coord{c}(:,3), edge_coord{c}(:,4), 'g')
    end

    % annotation
    text(P_start(c,1) + text_offs, P_start(c,2) + text_offs, channel_label(c), 'Color', 'm')
    pause(0.01) % just to force matlab to plot
    hold off
    % label for shapefile
    fchannel{c} = channel_label(c); 
    
end

disp(append("Finished mapping. End point reached for ", string(sum(channel_status)), "/", string(length(channel_status)), " channels. "))


%% write to files

if save_figs || save_shps || save_struct || save_table
    disp("Writing figure-, shapefiles-, and .mat... ")

    % print overview figure to file
    if save_figs
        %f.WindowState = 'maximized'; % make figure fullscreen before saving
        fn = append(fig_dir, file_prefix, 'mapped_channels'); 
        print(fn, figs_filetype, figs_resolution)
        %f.WindowState = 'normal'; 
    end
    
    % write mapped geometries to shapefile
    if save_shps
    
        % all centerlines in a single file
        fn = append(shp_dir, file_prefix, 'all_centerlines'); 
        lines_to_shp(x_cent, y_cent, R, fn, 'channel_label', fchannel); 
        
        % centerlines and outlines in one file per channel
        for c = 1:no_channels
            outlines_x = cell(3, 1); 
            outlines_y = cell(3, 1); 
            outlines_x{1} = x_cent{c};            % centerline
            outlines_y{1} = y_cent{c}; 
            outlines_x{2} = edge_coord{c}(:,1);   % left edge
            outlines_y{2} = edge_coord{c}(:,2); 
            outlines_x{3} = edge_coord{c}(:,3);   % right edge
            outlines_y{3} = edge_coord{c}(:,4); 
            fline = {"centerline", "left_edge", "right_edge"}; 
            fn = append(shp_dir, file_prefix, channel_label(c), "_outlines"); 
            lines_to_shp(outlines_x, outlines_y, R, fn, 'line_type', fline);
        end
        
        % all profile transects in one file per channel
        for c = 1:no_channels
            no_profiles = size(x_prof{c}, 2); 
            fprof = 1:no_profiles;  
            fn = append(shp_dir, file_prefix, channel_label(c), "_profiles"); 
            lines_to_shp(x_prof{c}, y_prof{c}, R, fn, 'prof_no', fprof);
        end 
    end

    if save_struct
        % create structure
        raw_struct = struct;
        raw_struct.created = datetime('now');
        raw_struct.updated = datetime('now');
        raw_struct.DEM_path = path_to_DEM;
        raw_struct.resolution = res;
        raw_struct.validation_methods = validation_methods;
        raw_struct.edge_detection_emthod = edge_method;
        raw_struct.knee_method = knee_method;
        
        % iterate trhough channels saving them out
        channels_struct = cell(no_channels, 1);
        for c = 1:no_channels
            channel = struct;

            channel.length = channel_length{c};
            channel.end_found = channel_status(c);
            channel.width = channel_width(c);
            channel.cent_coordinate = [x_cent{c}, y_cent{c}];


            % iterate through the channels profiles saving them out
            no_profiles = size(profiles{c}, 2);
            profiles_struct = cell(no_profiles, 1); 
            for p = 1:no_profiles
                profile = struct;
                profile.elevation = profiles{c}(:, p);
                profile.x_coordinates = x_prof{c}(:, p);
                profile.y_coordinates = y_prof{c}(:, p);

                profile.left_edge_elevation = edge_elev{c}(p, 1);
                profile.right_edge_elevation = edge_elev{c}(p, 2);
                profile.left_edge_coordinates = edge_coord{c}(p, 1:2);
                profile.right_edge_coordinates = edge_coord{c}(p, 3:4);

                profile.trough = trough_elev{c}(p);
                profile.trough_depth = trough_depth{c}(p);

                profiles_struct{p} = profile;
            end
            channel.profiles = profiles_struct;

            channels_struct{c} = channel;
        end
        raw_struct.channels = channels_struct;

        fn = append(data_dir, file_prefix, 'struct_data', '.mat');
        save(fn, 'raw_struct');
    end

    disp(append("Done writing files. Check '", append(results_dir, proj_subdir), "' for output. "))
end


%% extended figures
%  cross sectional profiles, metrics along channel length etc.

if ext_figs
disp("Creating and possibly saving extended figures. Sit tight. ")
    
    for c = 1:no_channels
        
        % filter array based on validation
        all_profiles = profiles{c};
        profiles{c} = all_profiles(:, keep_prof{c});
        all_edge_idx = edge_idx{c};
        edge_idx{c} = all_edge_idx(keep_prof{c}, :);
        all_edge_elev = edge_elev{c};
        edge_elev{c} = all_edge_elev(keep_prof{c}, :);
        all_trough_elev = trough_elev{c};
        trough_elev{c} = all_trough_elev(keep_prof{c}, :);
        all_trough_depth = trough_depth{c};
        trough_depth{c} = all_trough_depth(keep_prof{c}, :);

        % cross sectional profiles
        no_profiles = size(profiles{c}, 2); 
        
        % for plotting profiles with [m] on x-axis
        prof_dist_vector = (1:size(profiles{c}, 1))*res; 
        prof_dist_vector = prof_dist_vector - mean(prof_dist_vector);
        valid_l = ~isnan(edge_idx{c}(:,1));
        valid_r = ~isnan(edge_idx{c}(:,2));
        ledge_pos = NaN(no_profiles, 1);
        redge_pos = NaN(no_profiles, 1);
        ledge_pos(valid_l) = prof_dist_vector(edge_idx{c}(valid_l, 1)');
        redge_pos(valid_r) = prof_dist_vector(edge_idx{c}(valid_r, 2)');
        edge_pos_vector = [ledge_pos(:), redge_pos(:)];

        % color gradient shared across both profile figures
        cmap = parula(no_profiles);

        % full cross sectional profiles using absolute elevation
        figure(config_num*100000+c*100+1)
        hold on
        set(gca(), 'ColorOrder', cmap)
        plot(prof_dist_vector, profiles{c}, 'LineWidth', 3)
        xlabel('distance from profile center [m]')
        ylabel('elevation [m]')
        title(append(channel_label(c), ' cross sectional profiles (full, abs. heights)'))
        hcb = colorbar;
        title(hcb, 'norm. dist. along channel [-]')
        plot(edge_pos_vector, edge_elev{c}, 'o', 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'w', 'MarkerSize', 7)
        if save_figs
            fn = append(fig_dir, file_prefix, channel_label(c), '_full_profiles_elev');
            print(fn, figs_filetype, figs_resolution)
        end

        % between channel edges using relative elevation (depth w.r.t. left channel edge)
        figure(config_num*100000+c*100+2)
        hold on
        for i = 1:no_profiles
            if isnan(edge_idx{c}(i,1)) || isnan(edge_idx{c}(i,2))
                continue
            end

            prof = profiles{c}(:,i);

            % replace values outside of channel edges to NaN (keep edge points)
            prof(1:edge_idx{c}(i,2)-1) = NaN;
            prof(edge_idx{c}(i,1)+1:end) = NaN;

            % from absolute height to depth below left channel edge
            prof = prof - edge_elev{c}(i,1);

            plot(prof_dist_vector, prof, 'Color', cmap(i,:), 'LineWidth', 3)
        end
        xlabel('distance from profile center [m]')
        ylabel('depth [m]')
        title(append(channel_label(c), ' channel cross sectional profiles (depth below left edge)'))
        hcb = colorbar;
        title(hcb, 'norm. dist. along profile [-]')

        if save_figs
            fn = append(fig_dir, file_prefix, channel_label(c), '_lim_profiles_depth'); 
            print(fn, figs_filetype, figs_resolution)
        end
        
        
        % plotting some metrics along channel length
        norm_dist_vector = (1:no_profiles)./no_profiles; 
        
        figure(config_num*100000+c*100+3)
        hold on
        plot(norm_dist_vector*channel_length{c}/1000, mean(profiles{c}))
        ylabel('elevation [m]')
        xlabel('distance along channel [km]')
        title('mean profile elevation (full) vs. distance along channel')
        legend(channel_label(c))

        if save_figs
            fn = append(fig_dir, file_prefix, 'elev_vs_distance_along_channel'); 
            print(fn, figs_filetype, figs_resolution)
        end

        channel_width = (edge_idx{c}(:,1)-edge_idx{c}(:,2))*res; % [m]
        

        figure(config_num*100000+c*100+4)
        hold on
        plot(norm_dist_vector*channel_length{c}/1000, trough_depth{c}*1)
        ylabel('depth w.r.t. left channel edge [m]')
        xlabel('distance along channel [km]')
        title('channel depth vs. distance along channel')
        legend(channel_label(c))

        if save_figs
            fn = append(fig_dir, file_prefix, 'depth_vs_distance_along_channel'); 
            print(fn, figs_filetype, figs_resolution)
        end

        
        figure(config_num*100000+c*100+5)
        hold on
        plot(norm_dist_vector*channel_length{c}/1000, channel_width/1000)
        ylabel('channel width [km]')
        xlabel('distance along channel [km]')
        title('channel width vs. distance along channel')
        legend(channel_label(c))

        if save_figs
            fn = append(fig_dir, file_prefix, 'width_vs_distance_along_channel'); 
            print(fn, figs_filetype, figs_resolution)
        end


        % edge and trough elevation and depth along channel (one figure per channel)
        figure(config_num*100000+c*100+6)

        subplot(2, 1, 1)
        hold on
        plot(norm_dist_vector*channel_length{c}/1000, edge_elev{c}(:,1), 'Color', [0.0 0.6 0.0])
        plot(norm_dist_vector*channel_length{c}/1000, edge_elev{c}(:,2), 'Color', [0.4 0.8 0.4])
        plot(norm_dist_vector*channel_length{c}/1000, trough_elev{c},    'r')
        ylabel('elevation [m]')
        title(append(channel_label(c), ' edge and trough elevation along channel'))
        legend('left edge', 'right edge', 'trough')

        subplot(2, 1, 2)
        hold on
        plot(norm_dist_vector*channel_length{c}/1000, zeros(no_profiles, 1),                    'Color', [0.0 0.6 0.0])
        plot(norm_dist_vector*channel_length{c}/1000, edge_elev{c}(:,2) - edge_elev{c}(:,1),   'Color', [0.4 0.8 0.4])
        plot(norm_dist_vector*channel_length{c}/1000, trough_depth{c},                          'r')
        xlabel('distance along channel [km]')
        ylabel('depth w.r.t. left edge [m]')
        legend('left edge', 'right edge', 'trough')

        if save_figs
            fn = append(fig_dir, file_prefix, channel_label(c), '_edge_trough_along_channel');
            print(fn, figs_filetype, figs_resolution)
        end
    end
end
    
disp("Done! ")
