# filename = "error_list_MRI_to_US.txt"
# filename = "error_list_MRI_to_US_1.txt"
# filename = "error_lists/BITE_MRI_to_US.txt"
# filename = "error_list_MRI_to_US_deeds_dramms.txt"
filename = "error_lists/error_list_MRI_to_US_deeds_dramms_02mm_w_1.txt"
filename = "error_lists/BITE_MRI_to_US_02mm_w_0.txt"
filename = "error_lists/error_list_MRI_to_US_deeds_dramms_03mm_w_1.txt"
filename = "error_lists/BITE_MRI_to_US_04mm_w_0.txt"


vox_size = 0.5

with open(filename) as f:
    mean_err = 0
    num_el = 0
    for line in f:
        err = line.split()[-1].replace(")", "")
        if err!="nan":
            mean_err += float(err)
            num_el += 1

    mean_err = mean_err / num_el
    print(f"mTRE =  {mean_err:.3f}vox = {mean_err*vox_size:.3f}mm")

# Running processes on gpu05, curve11