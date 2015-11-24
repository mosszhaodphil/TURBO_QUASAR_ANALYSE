

data=QUASIL_RAW_11
((n_dynamics=2))
((n_tis=11))
((n_repeats=1))
((n_actual_tis=$n_tis*$n_dynamics*n_repeats))
((n_phases=7))
echo "Total number of sampling points: " $n_actual_tis " TIs"

# break out all TIs
# Output file name is ti1, ti2, ... tiXYZ
asl_file --data=$data --ntis=$n_actual_tis --ibf=tis --iaf=ct --split=ti

# Within each TI: separate the phases 
for ((i=0; i<$n_actual_tis; i++)); do
  mkdir ti$i
  tifile=`ls ti$i.nii.gz ti0$i.nii.gz ti00$i.nii.gz 2>/dev/null`
  echo $tifile
  asl_file --data=$tifile --ntis=$n_phases --ibf=rpt --iaf=ct --split=ti$i/phs
  # NB using asl_file to split the phases (pseudo TIs)
  # leaves TC pairs together
done

#now assemble the multiTI files
phslist=""
for ((j=0; j<$n_phases; j++)); do
  # within each phase
  filelist=""
  for ((i=0; i<$n_actual_tis; i++)); do
    # within each TI
    filelist=$filelist" ti$i/phs00$j"
  done
  
  fslmerge -t aslraw_ph$j $filelist
  # take mean within TI
  #asl_file --data=aslraw_ph$j --ntis=$n_actual_tis --ibf=tis --iaf=tc --mean=aslraw_ph$j
  phslist=$phslist" aslraw_ph$j"
done
fslmerge -t aslraw $phslist

# extract tag and control images for full dynamics
asl_file --data=aslraw --ntis=$n_actual_tis --ibf=tis --iaf=ct --spairs --out=aslraw
immv aslraw_odd asltag
immv aslraw_even aslcontrol

# reduce sampling rate or extract tag and control images for dynamic 1 and 2
asl_file --data=aslcontrol --ntis=77 --ibf=tis --iaf=ct --spairs --out=aslcontrol
immv aslcontrol_odd aslcontrol_dynamic_1
immv aslcontrol_even aslcontrol_dynamic_2

asl_file --data=asltag --ntis=77 --ibf=tis --iaf=ct --spairs --out=asltag
immv asltag_odd asltag_dynamic_1
immv asltag_even asltag_dynamic_2

# Tag control difference
asl_file --data=aslraw --ntis=$n_actual_tis --ibf=tis --iaf=ct --diff --out=asldata_diff
fslmaths asltag_dynamic_1 -sub aslcontrol_dynamic_1 asldata_diff_dynamic_1
fslmaths asltag_dynamic_2 -sub aslcontrol_dynamic_2 asldata_diff_dynamic_2

# discard the final (low flip angle) phase from the differenced data
# we do not (currently) use this for the main analysis
((nkeep_full_dynamic=$n_actual_tis * 6))
((nkeep_single_dynamic=$n_tis * 6))
fslroi asldata_diff asldata_diff_first_6 0 $nkeep_full_dynamic
fslroi asldata_diff_dynamic_1 asldata_diff_dynamic_1_first_6 0 $nkeep_single_dynamic
fslroi asldata_diff_dynamic_2 asldata_diff_dynamic_2_first_6 0 $nkeep_single_dynamic

# Make tissue (crushed) and blood (noncrushed - crushed) data
asl_file --data=asldata_diff_first_6 --ntis=6 --ibf=tis --iaf=diff --split=asldata_ph
fslmaths asldata_ph002 -add asldata_ph005 -mul 0.5 asl_nocrush
fslmaths asldata_ph000 -add asldata_ph001 -add asldata_ph003 -add asldata_ph004 -mul 0.25 asl_tissue
fslmaths asl_nocrush -sub asl_tissue asl_blood

asl_file --data=asldata_diff_dynamic_1_first_6 --ntis=6 --ibf=tis --iaf=diff --split=asldata_ph
fslmaths asldata_ph002 -add asldata_ph005 -mul 0.5 asl_nocrush_dynamic_1
fslmaths asldata_ph000 -add asldata_ph001 -add asldata_ph003 -add asldata_ph004 -mul 0.25 asl_tissue_dynamic_1
fslmaths asl_nocrush_dynamic_1 -sub asl_tissue_dynamic_1 asl_blood_dynamic_1

asl_file --data=asldata_diff_dynamic_2_first_6 --ntis=6 --ibf=tis --iaf=diff --split=asldata_ph
fslmaths asldata_ph002 -add asldata_ph005 -mul 0.5 asl_nocrush_dynamic_2
fslmaths asldata_ph000 -add asldata_ph001 -add asldata_ph003 -add asldata_ph004 -mul 0.25 asl_tissue_dynamic_2
fslmaths asl_nocrush_dynamic_2 -sub asl_tissue_dynamic_2 asl_blood_dynamic_2

# Generate mask
fslmaths aslcontrol -Tmean aslmean
bet aslmean mask -m

# Split the ASL control data into phases
asl_file --data=aslcontrol --ntis=7 --ibf=tis --iaf=diff --split=aslcontrol_ph
asl_file --data=aslcontrol_dynamic_1 --ntis=7 --ibf=tis --iaf=diff --split=aslcontrol_dynamic_1_ph
asl_file --data=aslcontrol_dynamic_2 --ntis=7 --ibf=tis --iaf=diff --split=aslcontrol_dynamic_2_ph

# Average the first six phases
fslmaths aslcontrol_ph000 -add aslcontrol_ph001 -add aslcontrol_ph002 -add aslcontrol_ph003 -add aslcontrol_ph004 -add  aslcontrol_ph005 -div 6.0 aslcontrol_avg
fslmaths aslcontrol_dynamic_1_ph000 -add aslcontrol_dynamic_1_ph001 -add aslcontrol_dynamic_1_ph002 -add aslcontrol_dynamic_1_ph003 -add aslcontrol_dynamic_1_ph004 -add  aslcontrol_dynamic_1_ph005 -div 6.0 aslcontrol_dynamic_1_avg
fslmaths aslcontrol_dynamic_2_ph000 -add aslcontrol_dynamic_2_ph001 -add aslcontrol_dynamic_2_ph002 -add aslcontrol_dynamic_2_ph003 -add aslcontrol_dynamic_2_ph004 -add  aslcontrol_dynamic_2_ph005 -div 6.0 aslcontrol_dynamic_2_avg


# Calibration: calculate voxel-wise T1 and M0
# Fit saturation recovery curve
fabber --data=aslcontrol_avg --data-order=singlefile --output=calib -@ calib_options.txt
fabber --data=aslcontrol_dynamic_1_avg --data-order=singlefile --output=calib_dynamic_1 -@ calib_options_dynamic_1.txt
fabber --data=aslcontrol_dynamic_2_avg --data-order=singlefile --output=calib_dynamic_2 -@ calib_options_dynamic_2.txt

# -div $tempdir/calib/M0t -mul 0.9 
calib_factor_full=" -div calib/mean_M0t -mul 0.9 -mul 6000"
calib_factor_dynamic_1=" -div calib_dynamic_1/mean_M0t -mul 0.9 -mul 6000"
calib_factor_dynamic_2=" -div calib_dynamic_2/mean_M0t -mul 0.9 -mul 6000"


# Model-fitting
fabber --data=asl_tissue --data-order=singlefile --output=full -@ fabber_options.txt
fabber --data=asldata_diff_first_6 --data-order=singlefile --output=full -@ fabber_options.txt
fabber --data=asl_tissue_dynamic_1 --data-order=singlefile --output=full_dynamic_1 -@ fabber_options_dynamic_1.txt
fabber --data=asl_tissue_dynamic_2 --data-order=singlefile --output=full_dynamic_2 -@ fabber_options_dynamic_2.txt

# Calibration
fslmaths full/mean_ftiss $calib_factor_full full/perfusion
fslmaths full_dynamic_1/mean_ftiss $calib_factor_full full_dynamic_1/perfusion
fslmaths full_dynamic_2/mean_ftiss $calib_factor_full full_dynamic_2/perfusion


#((nkeep_full_dynamic=$n_actual_tis * 6))
#((nkeep_single_dynamic=$n_tis * 6))
#fslroi aslcontrol_dynamic_1 aslcontrol_dynamic_1_first_6 0 $nkeep_single_dynamic
#fslmerge -t aslcontrol_ph01234 aslcontrol_ph000 aslcontrol_ph001 aslcontrol_ph002 aslcontrol_ph003 aslcontrol_ph004


