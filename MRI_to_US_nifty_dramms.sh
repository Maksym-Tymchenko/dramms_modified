#!/bin/sh

# Input arguments

case_num=${1-"2"}
image_folder=${2:-"bucket/RESECT/RESECT/NIFTI/Case${case_num}"}
us_image=${3:-"${image_folder}/US/Case${case_num}-US-before.nii.gz"}
mri_image=${4:-"${image_folder}/MRI/Case${case_num}-FLAIR.nii.gz"}
tag_file=${5:-"${image_folder}/Landmarks/Case${case_num}-MRI-beforeUS.tag"}

# Create directory to store the outputs
mkdir -p $image_folder/output/dramms

output_folder="$image_folder/output/dramms"

# Resample images into a common reference frame and isotropic voxel size of 1x1x1 mm
vox_size=0.5

c3d $us_image $mri_image -reslice-identity -resample-mm ${vox_size}x${vox_size}x${vox_size}mm -o $output_folder/Case${case_num}-MRI_in_US.nii.gz
c3d $us_image -resample-mm ${vox_size}x${vox_size}x${vox_size}mm -o $output_folder/Case${case_num}-US.nii.gz

# Generate 2 text files containing landmarks
python3 ./landmarks_split_txt.py --inputtag $tag_file --savetxt $output_folder/Case${case_num}_lm

# Generate landmark segmentations as a NIFTI file
c3d $output_folder/Case${case_num}-MRI_in_US.nii.gz -scale 0 -landmarks-to-spheres $output_folder/Case${case_num}_lm_mri.txt 1 -o $output_folder/Case${case_num}-MRI-landmarks.nii.gz
c3d $output_folder/Case${case_num}-US.nii.gz -scale 0 -landmarks-to-spheres $output_folder/Case${case_num}_lm_us.txt 1 -o $output_folder/Case${case_num}-US-landmarks.nii.gz


# Extract US background (pixels with 0 intensity exactly)
c3d $output_folder/Case${case_num}-US.nii.gz -threshold 0 0 0 1 -o $output_folder/mask_US.nii.gz


# Perform affine registration step
reg_aladin -ref $output_folder/Case${case_num}-US.nii.gz \
-flo $output_folder/Case${case_num}-MRI_in_US.nii.gz \
-res $output_folder/Case${case_num}-MRI_in_US_rigid.nii.gz \
-rmask $output_folder/mask_US.nii.gz \
-fmask $output_folder/mask_US.nii.gz \
-aff $output_folder/affine_matrix.txt \
-rigOnly


# Apply the transformation to the landmarks
reg_resample -ref $output_folder/Case${case_num}-US.nii.gz \
-flo $output_folder/Case${case_num}-MRI-landmarks.nii.gz \
-res $output_folder/Case${case_num}-MRI-landmarks_rotated.nii.gz \
-trans $output_folder/affine_matrix.txt \
-inter 0


# Perform multimodal registartion using -w 1 option (CC coefficient) important for multimodal registration
dramms -S $output_folder/Case${case_num}-MRI_in_US_rigid.nii.gz\
 -T $output_folder/Case${case_num}-US.nii.gz\
 -O $output_folder/Case${case_num}-MRI_to_US_deformed_result.nii.gz\
 -D $output_folder/Case${case_num}-MRI_to_US_def.nii.gz\
 -L $output_folder/Case${case_num}-MRI-landmarks_rotated.nii.gz\
 -W $output_folder/Case${case_num}_deformed_seg.nii.gz\
 -r 0\
 -w 1
 # -g 0.2 # -w 1 recommended for multimodal

# Calculate mTRE
python3 ./landmarks_centre_mass.py --inputnii $output_folder/Case${case_num}-US-landmarks.nii.gz \
--movingnii $output_folder/Case${case_num}_deformed_seg.nii.gz \
--savetxt $output_folder/Case${case_num}-results

# Remove unnecessary files
rm $output_folder/Case${case_num}_lm*
rm $output_folder/Case${case_num}-results*
