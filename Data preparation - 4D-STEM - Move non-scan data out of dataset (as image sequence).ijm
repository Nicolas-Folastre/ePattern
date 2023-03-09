/*
 * 	This macro is made to keep a defined number of consecutive images of an image sequence. 
 * 	It moves the not-kept images (before & after the serie to keep) in a separate folder.
 * 	
 * 	HOW TO USE
 * 	
 * 	run macro
 * 	select input folder, type of file and number of images to keep of image sequence.
 * 	The number of images to keep is the product of scan width and scan height (sliders).
 * 	By default the maximum possible scan height is taken to keep the maximum number of scan lines.
 * 	User sets the slice of the stack of the first image to keep. Press OK.
 * 	It copie the excess files in a separate folder (same roof) and delete them from input folder.
 * 	
 */

#@ File (label = "Input directory", style = "directory") input ;
#@ String (label = "File suffix", value = ".bmp") suffix ; 
#@ String (value="Number of slices from the beginning to check the beginning of scan", visibility="MESSAGE") hint ;
//#@ int(value=5, min=0, max=500, style="slider") N ;
#@ int(value=105, min=0, max=1000, style="slider") scan_width ;
#@ int(value=100, min=0, max=1000, style="slider") scan_height ;
keep = scan_width*scan_height;

WorkDir= File.getParent(input);
name = "randomstring";
name = File.getName(input);
output= File.makeDirectory(WorkDir+"\\"+name+"_excess");
output=WorkDir+"\\"+name+"_excess";
filelist = getFileList(input);

N=lengthOf(filelist);

IJ.log(input +" \n "+ output +" \n openned : "+ N +" / total : "+lengthOf(filelist));



//run("Image Sequence...", "select=E:/DATA_TEM_Gozde_Nicolas/2021-11-10_Gozde_LMNO_disordered_sans_recuit_P0/TESTS/test_astar_2_grouped_256p_8b_bmp/ dir=E:/DATA_TEM_Gozde_Nicolas/2021-11-10_Gozde_LMNO_disordered_sans_recuit_P0/TESTS/test_astar_2_grouped_256p_8b_bmp/ start=77 count=200 sort use");

run("Image Sequence...", "select="+input+" dir="+input+" start="+1+" count="+N+" sort use");

  ID = getImageID();
  title = "Select Beginning of Scan";
  msg = "Set Stack to the slice where the scan begins, then click \"OK\". \n Images of the stack that are not part of the scan will be moved here : \n "+output;
  waitForUser(title, msg);
  selectImage(ID);  //make sure we still have the same image
  first_slice_scan=getSliceNumber();
  for (j = 0; j < 1000; j++) { //find the maximum number of lines to keep
  	if (first_slice_scan+keep+j*scan_width < N) {
		 last_slice=first_slice_scan+keep+j*scan_width; //keep is the expected number of lines * width, j is extra eventual lines
  	}
  }


setBatchMode("hide");
close("*");

IJ.log("Last slice of scan : "+last_slice-1+" / "+N-(last_slice-1)+" images to move at the end");
IJ.log("scan "+scan_width+"/"+scan_height+" : "+keep+" images to keep");
IJ.log(first_slice_scan-1+" images to move at the beginning");

//	COPY

//Copy the beginning images to excess folder

for (i = 0; i < first_slice_scan-1; i++) {
	File.copy(input + File.separator + filelist[i], output + File.separator +  filelist[i]);
}

// Copy the final images to excess folder

for (i = last_slice-1; i < lengthOf(filelist); i++) {
	File.copy(input + File.separator + filelist[i], output + File.separator +  filelist[i]);
}


//	DELETE

delete=1;

if (delete) {

//Delete the beginning slices from the source folder

for (i = 0; i < first_slice_scan-1; i++) {
	File.delete(input + File.separator + filelist[i]);
}

//delete the end slices from source folder

for (i = last_slice-1; i < lengthOf(filelist); i++) {
	File.delete(input + File.separator + filelist[i]);
}



}

//Finalize
close("*");

setBatchMode("exit and display");
//update scan height value
scan_height = (last_slice-first_slice_scan)/scan_width;
Rename_Folder(input, name+"_(0-"+(scan_height-1)+",0-"+(scan_width-1)+")");
IJ.log("Scan Size : ("+scan_width+" - "+scan_height+")");
IJ.log("Files copied in new folder and deleted from source folder");
IJ.log("Old name of source folder : "+name);
IJ.log("New name of source folder : "+name);

function Rename_Folder(path1, new_name_folder) { 
// Rename the last folder of path
old_name_folder = File.getName(path1);
index_folder = lastIndexOf(path1, old_name_folder);
path2 = substring(path1, 0, index_folder)+new_name_folder+File.separator;
File.rename(path1, path2);
}
