# The input file should be organised like this:
# Four big chuncks (1 regular chunck * 2 shifts * 2 repeats)
# Each dynamic has seven dynamics (Crushed, Crushed, Non-crushed, Crushed, Crushed, Non-crushed, Low flip angle)
# Each dynamic has 11 TIs (called cardca phases in Philips PAR file)
# Each TI has control and tag pairs

# Input data
data_input=test3

((n_dynamics=7))
((n_shift=2))
((n_tis=11))
((n_repeats=1))
((n_tc=2))
((n_dynamics_useful=6)) # dynamics that are useful, currently six (discard last flip angle)

# Total number of TIs in each shift excluding tag-control pairs
((n_actual_tis_shift=$n_tis*$n_dynamics))
# Total number of TIs in each shift including tag-control pairs
((n_actual_tis_shift_tc=$n_tis*$n_dynamics*$n_tc))
# Total number of TIs in each repeat
((n_actual_tis_repeats=$n_tis*$n_dynamics*$n_shift*$n_tc))
# Total number of TIs in the entire dataset
((n_actual_tis_data=$n_tis*$n_dynamics*$n_shift*$n_tc*$n_repeats))
# First six dynamics
((n_actual_tis_first_six_dynamics=$n_tis*$n_dynamics_useful))

echo "Total number of sampling points: " $n_actual_tis_repeats " TIs"

# Split the two shifts
#fslroi test2 data_dynamic_1_repeat_1 0 $n_actual_tis_shift_tc
#fslroi test2 data_dynamic_2_repeat_1 $n_actual_tis_shift_tc $n_actual_tis_shift_tc
#fslroi test2 data_dynamic_1_repeat_2 $n_actual_tis_repeats $n_actual_tis_shift_tc
#fslroi test2 data_dynamic_2_repeat_2 $haha $n_actual_tis_shift_tc

#fslmaths data_dynamic_1_repeat_1 -add data_dynamic_1_repeat_2 -div 2 data_mean_shift_1
#fslmaths data_dynamic_2_repeat_1 -add data_dynamic_2_repeat_2 -div 2 data_mean_shift_2


# Take the mean of all repeats
asl_file --data=$data_input --ntis=$n_actual_tis_repeats --ibf=rpt --mean=data_mean

# Split the two shifts
# fslroi <input> <output> <starting TI> <total number of TIs>
fslroi data_mean data_mean_shift_1 0 $n_actual_tis_shift_tc
fslroi data_mean data_mean_shift_2 $n_actual_tis_shift_tc $n_actual_tis_shift_tc

# Extract tag control

# Take tag control difference
asl_file --data=data_mean_shift_1 --ntis=$n_actual_tis_shift --iaf=ct --diff --out=data_mean_shift_1_diff
asl_file --data=data_mean_shift_2 --ntis=$n_actual_tis_shift --iaf=ct --diff --out=data_mean_shift_2_diff

# Extract first six dynamics
fslroi data_mean_shift_1_diff data_mean_shift_1_diff_first_6 0 $n_actual_tis_first_six_dynamics
fslroi data_mean_shift_2_diff data_mean_shift_2_diff_first_6 0 $n_actual_tis_first_six_dynamics

# Extract the tissue component (average four crushed dynamics)
asl_file --data=data_mean_shift_1_diff_first_6 --ntis=$n_dynamics_useful --ibf=tis --iaf=diff --split=data_mean_shift_1_dynamic_
fslmaths data_mean_shift_1_dynamic_002 -add data_mean_shift_1_dynamic_005 -mul 0.5 asl_shift_1_non_crushed
fslmaths data_mean_shift_1_dynamic_000 -add data_mean_shift_1_dynamic_001 -add data_mean_shift_1_dynamic_003 -add data_mean_shift_1_dynamic_004 -mul 0.25 asl_shift_1_tissue
fslmaths asl_shift_1_non_crushed -sub asl_shift_1_tissue asl_shift_1_blood

asl_file --data=data_mean_shift_2_diff_first_6 --ntis=$n_dynamics_useful --ibf=tis --iaf=diff --split=data_mean_shift_2_dynamic_
fslmaths data_mean_shift_2_dynamic_002 -add data_mean_shift_2_dynamic_005 -mul 0.5 asl_shift_2_non_crushed
fslmaths data_mean_shift_2_dynamic_000 -add data_mean_shift_2_dynamic_001 -add data_mean_shift_2_dynamic_003 -add data_mean_shift_2_dynamic_004 -mul 0.25 asl_shift_2_tissue
fslmaths asl_shift_2_non_crushed -sub asl_shift_2_tissue asl_shift_2_blood




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


