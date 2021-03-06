function plot_reverse_depth_classification_results_subjects(subjects, contrast, varargin)

% Parse inputs
defaults = struct('data_dir','d:/meg_laminar/derivatives/spm12',...
    'surf_dir', 'D:/meg_laminar/derivatives/freesurfer','inv_type','EBB',...
    'patch_size',0.4,'recompute_roi',false);  %define default values
params = struct(varargin{:});
for f = fieldnames(defaults)',
    if ~isfield(params, f{1}),
        params.(f{1}) = defaults.(f{1});
    end
end

spm('defaults','eeg');
addpath('D:\meg_laminar\layer_comparison');

subject_whole_brain_tvals=zeros(1,length(subjects));
subject_func_roi_tvals=zeros(1,length(subjects));
subject_anatfunc_roi_tvals=zeros(1,length(subjects));

thresh_type='lower';
switch contrast.comparison_name
    case 'dots_beta_erd'
        thresh_type='upper';
    case 'dots_alpha'
        thresh_type='upper';
end
subj_dofs=zeros(1,length(subjects));

for subj_idx=1:length(subjects)
    subj_info=subjects(subj_idx);
    subj_surf_dir=fullfile(params.surf_dir,subj_info.subj_id);
    
    orig_white_mesh=fullfile(subj_surf_dir,'white.hires.deformed.surf.gii');
    white_mesh=fullfile(subj_surf_dir,'ds_white.hires.deformed.surf.gii');
    white_inflated=fullfile(subj_surf_dir,'ds_white.hires.deformed_inflated.surf.gii');
    orig_pial_mesh=fullfile(subj_surf_dir,'pial.hires.deformed.surf.gii');
    pial_mesh=fullfile(subj_surf_dir,'ds_pial.hires.deformed.surf.gii');
    pial_inflated=fullfile(subj_surf_dir,'ds_pial.hires.deformed_inflated.surf.gii');
    pial_white_map=map_pial_to_white(white_mesh, pial_mesh, 'mapType', 'link',...
        'origPial', orig_pial_mesh, 'origWhite', orig_white_mesh);
    white_pial_map=map_white_to_pial(white_mesh, pial_mesh, 'mapType', 'link',...
        'origPial', orig_pial_mesh, 'origWhite', orig_white_mesh);
    pial_hemisphere_map=get_hemisphere_map(pial_mesh, orig_pial_mesh);
    white_hemisphere_map=get_hemisphere_map(white_mesh, orig_white_mesh);
    wm=gifti(white_mesh);
    
    foi_dir=fullfile(params.data_dir, subj_info.subj_id,...
            sprintf('ses-%02d',subj_info.sessions(1)), 'grey_coreg', params.inv_type,....
            ['p' num2str(params.patch_size)], contrast.zero_event,...
            ['f' num2str(contrast.foi(1)) '_' num2str(contrast.foi(2))]);
    lfn_filename=fullfile(foi_dir, sprintf('br%s_%d.mat',subj_info.subj_id, subj_info.sessions(1)));    
    
    foi_dir=fullfile(params.data_dir, subj_info.subj_id,...
            'grey_coreg', params.inv_type,....
            ['p' num2str(params.patch_size)], contrast.zero_event,...
            ['f' num2str(contrast.foi(1)) '_' num2str(contrast.foi(2))]);
    % Get mean pial-wm in ROI
    pial_wm_diff=gifti(fullfile(foi_dir,['pial-white.' contrast.comparison_name '.diff.gii']));
            
    subj_dofs(subj_idx)=size(pial_wm_diff.cdata(:,:),2)-1;
    
    pial_depth_fname=fullfile(subj_surf_dir,'ds_pial_sulcal_depth.mat');
    wm_depth_fname=fullfile(subj_surf_dir,'ds_white_sulcal_depth.mat');
    if exist(pial_depth_fname,'file')~=1 || exist(wm_depth_fname,'file')~=2
        [pial_depth,HS]=compute_sulcal_depth(pial_mesh);
        mapping=dsearchn(HS.vertices,wm.vertices);
        wm_depth=sqrt(sum((wm.vertices-HS.vertices(mapping,:)).^2,2));
        save(pial_depth_fname,'pial_depth');
        save(wm_depth_fname,'wm_depth');
    else
        load(pial_depth_fname);
        load(wm_depth_fname);
    end
    mapped_wm_depth=wm_depth(pial_white_map);
    depth_diff=pial_depth-mapped_wm_depth;
    
    % whole brain
    [pial_mask,wm_mask,mask]=compute_roi(subj_info, foi_dir, contrast.comparison_name, ...
        thresh_type, pial_mesh, white_mesh, pial_inflated, white_inflated, ...
        pial_white_map, white_pial_map, lfn_filename, 'thresh_percentile',0,...
        'type','mean', 'region', '', 'hemisphere', '',...
        'pial_hemisphere_map', pial_hemisphere_map,...
        'white_hemisphere_map', white_hemisphere_map, 'recompute', params.recompute_roi);            
    
    % Add reverse depth to mask
    mask=intersect(mask, find(depth_diff>0));
    
    pial_wm_roi_diff=mean(pial_wm_diff.cdata(mask,:));
    [tstat,p]=ttest_corrected(pial_wm_roi_diff','correction',25*var(pial_wm_roi_diff));
    disp(sprintf('%s, whole=%.3f',subj_info.subj_id,tstat));
    subject_whole_brain_tvals(subj_idx)=tstat;
    
    % func ROI
    [pial_mask,wm_mask,mask]=compute_roi(subj_info, foi_dir, contrast.comparison_name, ...
        thresh_type, pial_mesh, white_mesh, pial_inflated, white_inflated, ...
        pial_white_map, white_pial_map, lfn_filename, 'thresh_percentile',80,...
        'type','mean', 'region', '', 'hemisphere', '',...
        'pial_hemisphere_map', pial_hemisphere_map,...
        'white_hemisphere_map', white_hemisphere_map, 'recompute', params.recompute_roi);            
    
    % Add reverse depth to mask
    mask=intersect(mask, find(depth_diff>0));
    
    pial_wm_roi_diff=mean(pial_wm_diff.cdata(mask,:));
    [tstat,p]=ttest_corrected(pial_wm_roi_diff','correction',25*var(pial_wm_roi_diff));
    disp(sprintf('%s, func=%.3f',subj_info.subj_id,tstat));
    subject_func_roi_tvals(subj_idx)=tstat;
    
    % anat-func ROI
    [pial_mask,wm_mask,mask]=compute_roi(subj_info, foi_dir, contrast.comparison_name, ...
        thresh_type, pial_mesh, white_mesh, pial_inflated, white_inflated, ...
        pial_white_map, white_pial_map, lfn_filename, 'thresh_percentile',80,...
        'type','mean', 'region', contrast.region, 'hemisphere', contrast.hemisphere,...
        'pial_hemisphere_map', pial_hemisphere_map,...
        'white_hemisphere_map', white_hemisphere_map, 'recompute', params.recompute_roi);            
    
    % Add reverse depth to mask
    mask=intersect(mask, find(depth_diff>0));
    
    pial_wm_roi_diff=mean(pial_wm_diff.cdata(mask,:));
    [tstat,p]=ttest_corrected(pial_wm_roi_diff','correction',25*var(pial_wm_roi_diff));
    disp(sprintf('%s, anat-func=%.3f',subj_info.subj_id,tstat));
    subject_anatfunc_roi_tvals(subj_idx)=tstat;    
end

fig=figure('Position',[1 1 1200 600],'PaperUnits','points',...
    'PaperPosition',[1 1 600 300],'PaperPositionMode','manual');
hold on;
bar_width=0.1;
gap_width=0.05;
subj_width=3*bar_width+(3-1)*gap_width;

subj_ids={};
alpha=1.0-(0.05/2);
t_thresh=tinv(alpha, mean(subj_dofs));
plot([1-.5 length(subjects)+.5],[t_thresh t_thresh],'k--','LineWidth',2);
plot([1-.5 length(subjects)+.5],[-t_thresh -t_thresh],'k--','LineWidth',2);

    
for subj_idx=1:length(subjects)
    subj_info=subjects(subj_idx);
    subj_ids{subj_idx}=num2str(subj_idx);
    left=subj_idx-.5*subj_width;
        
    center=left+.5*bar_width+(1-1)*(bar_width+gap_width);
    tval=subject_whole_brain_tvals(subj_idx);
    face_color=[0 39 102]./255.0;
    if tval<0
        face_color=[130 0 0]./255.0;
    end
    bar(center, tval, bar_width, 'FaceColor', face_color,'EdgeColor','none');
    
    center=left+.5*bar_width+(2-1)*(bar_width+gap_width);
    tval=subject_func_roi_tvals(subj_idx);
    face_color=[0 64 168]./255.0;
    if tval<0
        face_color=[200 0 0]./255.0;
    end
    bar(center, tval, bar_width, 'FaceColor', face_color,'EdgeColor','none');
    
    center=left+.5*bar_width+(3-1)*(bar_width+gap_width);
    tval=subject_anatfunc_roi_tvals(subj_idx);
    face_color=[0 97 255]./255.0;
    if tval<0
        face_color=[255 0 0]./255.0;
    end
    bar(center, tval, bar_width, 'FaceColor', face_color,'EdgeColor','none');            
end
set(gca,'XTick',1:length(subjects));
set(gca,'XTickLabel',subj_ids);
xlabel('Participant','Fontsize',24,'Fontname','Arial');
ylabel('Pial-White ROI t-statistic','Fontsize',24,'Fontname','Arial');
xlim([.5 length(subjects)+.5]);
yl=ylim;
ylim([-max(abs(yl)) max(abs(yl))]);
xt=get(gca,'XTick');
set(gca,'FontSize',20);
set(gca,'Fontname','Arial');

rmpath('D:\meg_laminar\layer_comparison');