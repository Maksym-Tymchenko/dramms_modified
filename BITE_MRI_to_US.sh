#!/bin/sh

# Input arguments
case_num=${1-"01"}
# image_folder=${2:-"bucket/BITE_group4/${case_num}/3D"}
image_folder=${2:-"bucket/BITE_group2_nii/${case_num}"}

us_image_uncompressed="US3DT.nii"
mri_image_uncompressed="MR.nii"
tag_file="bucket/BITE_group2_nii/BITE_group2_nii_tags/${case_num}/${case_num}_all.tag"

# Create directory to store the outputs
mkdir -p $image_folder/output/deeds

output_folder="$image_folder/output/deeds"

us_image="$output_folder/US3DT.nii.gz"
mri_image="$output_folder/MR.nii.gz"

# Compress images to match format expected by deedsBCV
gzip -fck $image_folder/$us_image_uncompressed > $us_image
gzip -fck $image_folder/$mri_image_uncompressed > $mri_image

# Resample images into a common reference frame and isotropic voxel size of 1x1x1 mm
vox_size=0.5

c3d $us_image $mri_image -reslice-identity -resample-mm ${vox_size}x${vox_size}x${vox_size}mm -o $output_folder/Case${case_num}-MRI_in_US.nii.gz
c3d $us_image -resample-mm ${vox_size}x${vox_size}x${vox_size}mm -o $output_folder/Case${case_num}-US.nii.gz

# Generate 2 text files containing landmarks
python3 ./landmarks_split_txt.py --inputtag $tag_file --savetxt $output_folder/Case${case_num}_lm

# Generate landmark segmentations as a NIFTI file
c3d $output_folder/Case${case_num}-MRI_in_US.nii.gz -scale 0 -landmarks-to-spheres $output_folder/Case${case_num}_lm_mri.txt 1 -o $output_folder/Case${case_num}-MRI-landmarks.nii.gz
c3d $output_folder/Case${case_num}-US.nii.gz -scale 0 -landmarks-to-spheres $output_folder/Case${case_num}_lm_us.txt 1 -o $output_folder/Case${case_num}-US-landmarks.nii.gz


# # Calculate linear rigid pre-registration using deeds
# ../deedsBCV/linearBCV -F $output_folder/Case${case_num}-US.nii.gz \
#  -M $output_folder/Case${case_num}-MRI_in_US.nii.gz \
#  -R 1 \
#  -O $output_folder/affine


# # Apply linear preregistration to landmarks
# python3 ../deedsBCV/generate_zero_displacements.py $output_folder $output_folder/Case${case_num}-MRI_in_US.nii.gz

# ../deedsBCV/applyBCV -M $output_folder/Case${case_num}-MRI-landmarks.nii.gz \
# -O $output_folder/zero \
# -D $output_folder/Case${case_num}-MRI-landmarks_rotated.nii.gz \
# -A $output_folder/affine_matrix.txt

#  ../deedsBCV/applyBCV -M $output_folder/Case${case_num}-MRI_in_US.nii.gz \
#  -O $output_folder/zero \
#  -D $output_folder/Case${case_num}-MRI_in_US_rigid.nii.gz \
#  -A $output_folder/affine_matrix.txt


# Perform multimodal registartion using -w 1 option (CC coefficient) important for multimodal registration
dramms -S $output_folder/Case${case_num}-MRI_in_US.nii.gz \
 -T $output_folder/Case${case_num}-US.nii.gz \
 -O $output_folder/Case${case_num}-MRI_to_US_deformed_result.nii.gz \
 -D $output_folder/Case${case_num}-MRI_to_US_def.nii.gz \
 -L $output_folder/Case${case_num}-MRI-landmarks.nii.gz \
 -W $output_folder/Case${case_num}_deformed_seg.nii.gz \
 -r 0 \
 -w 1 \
 -a 0
 # -g 0.2 # -w 1 recommended for multimodal

# Calculate mTRE
python3 ./landmarks_centre_mass.py --inputnii $output_folder/Case${case_num}-US-landmarks.nii.gz \
--movingnii $output_folder/Case${case_num}_deformed_seg.nii.gz \
--savetxt $output_folder/Case${case_num}-results

# Remove unnecessary files
rm $output_folder/Case${case_num}_lm*
rm $output_folder/Case${case_num}-results*
