% script for current_analysis_tool
global key_dir

[steering_file, working_dir] = uigetfile('*.txt', 'Select the steering file');
present_dir = cd(working_dir);

%% get files from steering files
STEERING = GetParameters(steering_file, [key_dir filesep 'steering.key']);

%% load the  configuration parameters
CONFIG_ADCP = GetParameters(STEERING.ADCP_config_file, [key_dir filesep 'ADCP.key']);
CONFIG_CURR = GetParameters(STEERING.CURR_config_file, [key_dir filesep 'current.key']);
CONFIG_TURB = GetParameters(STEERING.TURB_config_file, [key_dir filesep 'turbulence.key']);
%CONFIG_WAVE = GetParameters(STEERING.WAVE_config_file, [key_dir filesep 'wave.key']);

%% extract ADCP data
matlab_data_file = [strtok(STEERING.current_data_file, '.') '.mat'];
if ~exist(matlab_data_file, 'file')
    [RAW,CONFIG_CURR,CONFIG_ADCP] = feval(['curr_ADCP_Ensemble_BIN2RAW_' CONFIG_ADCP.current_ensemble_reader_version] ,STEERING.current_data_file, CONFIG_CURR, CONFIG_ADCP);
     
    save(matlab_data_file, 'RAW','CONFIG_ADCP', 'CONFIG_CURR', '-v7.3');
else
    disp('Using raw data saved in MAT file');
    load(matlab_data_file, 'RAW','CONFIG_ADCP', 'CONFIG_CURR');
end

%% update heading and depth
RAW.depth   = RAW.depth   + CONFIG_ADCP.ADCP_height;
RAW.heading = RAW.heading + CONFIG_ADCP.magnetic_variation;

%% update CONFIG parameters
%[CONFIG_CURR, CONFIG_ADCP] = feval(['curr_update_config_' CONFIG_CURR.curr_update_ver], CFG, CONFIG_CURR, CONFIG_ADCP);

%% trim RAW data
RAW = feval(['curr_trim_data_' CONFIG_CURR.curr_trim_data_ver],RAW, CONFIG_CURR, CONFIG_ADCP);

%% apply Tier 2 QC to ADCP data
RAW_QC = feval(['curr_QC_T2_' CONFIG_CURR.curr_qc_t2_ver],RAW, CONFIG_CURR, CONFIG_ADCP);

%% apply Tier 3 QC to ADCP data
RAW_QC = feval(['curr_QC_T3_' CONFIG_CURR.curr_qc_t3_ver],RAW_QC, CONFIG_CURR, CONFIG_ADCP);

%% Bin mapping in beam coordinates
RAW_QC.beam_vel_map = feval(['curr_bin_mapping_' CONFIG_CURR.curr_bin_map_ver],RAW_QC, CONFIG_CURR, CONFIG_ADCP);

%% convert beam to polar coordinates 
[PACKET_QC] = feval(['curr_beam2polar_' CONFIG_CURR.curr_beam2polar_ver],RAW_QC, CONFIG_ADCP, CONFIG_CURR);

%% packet data
% this has been put in the main tool to limit memory requirements
% RAW = feval(['current_packet_data_' CONFIG_CURR.current_packet_data_version], ADCP_RAW, CONFIG_CURR, CONFIG_ADCP);
%% define mean velocities, ancillary data and depth averaging 
CURRENT = feval(['curr_define_statistics_' CONFIG_CURR.curr_stat_ver], PACKET_QC);

%% define reference bins
CURRENT = feval(['curr_define_ref_bin_' CONFIG_CURR.curr_reference_bin_ver], CURRENT,CONFIG_ADCP, CONFIG_CURR);

%% Find best heading for flood and ebb
CURRENT = feval(['curr_best_heading_' CONFIG_CURR.curr_best_heading_ver], PACKET_QC, CURRENT,CONFIG_CURR, CONFIG_ADCP);

%% Calculate velocity shear
CURRENT = feval(['curr_vel_shear_' CONFIG_CURR.curr_vel_shear_ver], PACKET_QC, CURRENT,CONFIG_ADCP);

%% Define statistics of flood/ebb velocities in synodic months
CURRENT = feval(['curr_synodic_statistics_' CONFIG_CURR.curr_synodic_ver], CURRENT,CONFIG_CURR);

%% calculate joint probability of Magnitude and Direction
CURRENT = feval(['curr_joint_prob_' CONFIG_CURR.curr_joint_prob_ver], CURRENT,CONFIG_CURR);

%% Calculate power law for flood/ ebb
CURRENT = feval(['curr_power_law_' CONFIG_CURR.curr_power_law_ver], PACKET_QC,CURRENT, CONFIG_CURR);

%% Calculate std of Doppler noise
CURRENT =feval(['curr_variance_calc_' CONFIG_CURR.curr_var_calc_ver],CURRENT,PACKET_QC, CONFIG_CURR, CONFIG_ADCP);

%% Reynold/ Kinetic energy ane calculate turbulance intensity
CURRENT =feval(['curr_turb_intensity_' CONFIG_CURR.curr_turb_intensity_ver],CURRENT, PACKET_QC, CONFIG_CURR, CONFIG_ADCP);

%% calculate mean and std of turbulance itensity
CURRENT =feval(['curr_TI_statistics_' CONFIG_CURR.curr_TI_stat_ver],PACKET_QC, CURRENT, CONFIG_CURR);

%% save all data
save([CONFIG_ADCP.ADCP_ref '_processed_current_' datestr(now,'yymmddHHMM')], ...
     'CURRENT', 'PACKET_QC', 'CONFIG_CURR', 'CONFIG_ADCP', 'STEERING', '-v7.3');

%% return to original directory
cd(present_dir)