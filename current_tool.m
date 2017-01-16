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
[RAW_QC] = feval(['curr_beam2polar_' CONFIG_CURR.curr_beam2polar_ver],RAW_QC, CONFIG_ADCP, CONFIG_CURR);

%% packet data
% this has been put in the main tool to limit memory requirements

% RAW = feval(['current_packet_data_' CONFIG_CURR.current_packet_data_version], ADCP_RAW, CONFIG_CURR, CONFIG_ADCP);
[nping, nbin, ~] = size(RAW_QC.beam_vel);
npoint = CONFIG_CURR.lpacket * CONFIG_ADCP.fs;
npacket = floor(nping / npoint);
nbeam  = CONFIG_ADCP.nbeam;

% original order is [nens, nbin, nbeam]
PACKET_QC.beam_vel = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver],RAW_QC.beam_vel, npacket, npoint, nbin, nbeam);
RAW_QC = rmfield(RAW_QC, 'beam_vel');
PACKET_QC.beam_vel_map = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.beam_vel_map, npacket, npoint, nbin, nbeam);
RAW_QC = rmfield(RAW_QC, 'beam_vel_map');
PACKET_QC.QC_T2 = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.QC_T2, npacket, npoint, nbin, nbeam);
RAW_QC = rmfield(RAW_QC, 'QC_T2');
% final order is [npacket, npoint, nbin, nbeam]

% original order is [nens, nbin]
PACKET_QC.Vx = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver],RAW_QC.Vx, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'Vx');
PACKET_QC.Vy = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.Vy, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'Vy');
PACKET_QC.Vz = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.Vz, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'Vz');
PACKET_QC.error_vel = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.error_vel, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'error_vel');
PACKET_QC.Ve = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.Ve, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'Ve');
PACKET_QC.Vn = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.Vn, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'Vn');
PACKET_QC.Vv = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.Vv, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'Vv');
PACKET_QC.mag = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.mag, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'mag');
PACKET_QC.dir = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.dir, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'dir');
PACKET_QC.QC_T2_4BEAM = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.QC_T2_4BEAM, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'QC_T2_4BEAM');
PACKET_QC.QC_T2_3BEAM = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.QC_T2_3BEAM, npacket, npoint, nbin);
RAW_QC = rmfield(RAW_QC, 'QC_T2_3BEAM');
% final order is [npacket, npoint, nbin]

% original order is [nens, 1]
PACKET_QC.mtime = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.mtime, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'mtime');
PACKET_QC.roll = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.roll, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'roll');
PACKET_QC.pitch = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.pitch, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'pitch');
PACKET_QC.heading = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.heading, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'heading');
PACKET_QC.depth = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.depth, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'depth');
PACKET_QC.temperature = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.temperature, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'temperature');
PACKET_QC.pressure = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.pressure, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'pressure');
PACKET_QC.AnBit = feval(['curr_packet_var_' CONFIG_CURR.curr_packet_var_ver], RAW_QC.AnBit, npacket, npoint);
RAW_QC = rmfield(RAW_QC, 'AnBit');
% final order is [npacket, npoint]

%% define mean velocities, ancillary data and depth averaging 
CURRENT = feval(['curr_define_' CONFIG_CURR.curr_define_ver], PACKET_QC);

%% define reference bins
CURRENT = feval(['curr_define_ref_bin_' CONFIG_CURR.curr_reference_bin_ver], CURRENT,CONFIG_ADCP, CONFIG_CURR);

%% Find best heading for flood and ebb
CURRENT = feval(['curr_best_heading_' CONFIG_CURR.curr_best_heading_ver], PACKET_QC, CURRENT,CONFIG_CURR, CONFIG_ADCP);

%% Calculate velocity shear
CURRENT = feval(['curr_vel_shear_' CONFIG_CURR.curr_vel_shear_ver], PACKET_QC, CURRENT,CONFIG_ADCP);

%% Define statistics of flood/ebb velocities in synodic months
CURRENT = feval(['curr_define_statistics_' CONFIG_CURR.curr_define_stat_ver], CURRENT,CONFIG_CURR);

%% calculate joint probability of Magnitude and Direction
CURRENT = feval(['curr_joint_prob_' CONFIG_CURR.curr_joint_prob_ver], CURRENT,CONFIG_CURR);

%% Calculate power law for flood/ ebb
CURRENT = feval(['curr_power_law_' CONFIG_CURR.curr_power_law_ver], PACKET_QC,CURRENT);

%% turbulence analysis
CONFIG_TURB.vel_bin_width    = CONFIG_CURR.vel_bin_width;
CONFIG_TURB.lpacket          = CONFIG_CURR.lpacket;
CONFIG_TURB.start_date       = CONFIG_CURR.start_date;
TURBULENCE = feval(['turb_analysis_' CONFIG_TURBULENCE.turb_analysis_ver], CURRENT, PACKET_QC, CONFIG_TURB, CONFIG_ADCP);
TURBULENCE.ref_bin           = CURRENT.ref_bin;

%% save all data
save([CONFIG_ADCP.ADCP_ref '_processed_current_' datestr(now,'yymmddHHMM')], ...
     'CURRENT', 'TURBULENCE', 'PACKET_QC', 'RAW_QC', 'CONFIG_CURR', 'CONFIG_TURB', 'CONFIG_ADCP', 'STEERING', '-v7.3');

%% return to original directory
cd(present_dir)