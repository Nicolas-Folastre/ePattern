 /* Automatic Folder Process (Multifolder)- Spots Registration and Reconstruction V942 (align mean BG - Regs Regp_CSV Rec) - TESTING.ijm
 * 	
 * Author: Nicolas Folastre
 * 
 * This script has been developped to register the diffraction signal 
 * contained in 4D datasets and to reconstruct it as an image.
 */

Version = 9.0;

/* Strategy
 *  mean between lines and then along the mean line using alined patterns (on central spot position)
 *  Remove background of images								- 	option to write down as image sequence iline-jcolumn
 *  register the diffraction spots							-   option to assemble csv files in 1 main csv file
 * 															-   option to align in main csv file
 * 															-	1 line = 1 reflection : X Y in scan, X Y in pattern, Mean, radius
 * 															-v94: record StdDev of each slice at high angle
 *  Reconstruct the images									-   from csv line by line or at the end with the 1 csv file
 *  														-v941: Build of VBF, Full VBF, Spot count map, Standard deviation map, minimum prominence map
 *  														-v942: Option to build only maps without reconstructed patterns														
 *  write down as image sequence iline-jcolumn
 *  		
 *  
 *  TO DO : 
 *  		
 *	new alignment < 0.1px when open a line										OK
 *	conserve meaning between and along lines as Option							OK
 *  Add the function of spots registration > writes a file for each line.		OK
 *  Add Rebuild stack from registration											OK
 * 	Dialog and initialization to finish											OK
 * 	
 * 	  TO DO:  Comments everywhere / document
*/

print("\\Clear");
// Set folders to include + Choose work mode
#@ String (choices={"Registration", "Reconstruction", "Registration+Reconstruction",  "Mask no-background data", "Reg+Rec_Rapid"}, style="radioButtonHorizontal") Choice_macro
#@ String(value=" 'Mask no-background data' and 'Reg+Rec_Rapid' are still in development", visibility="MESSAGE") hint;
#@ File[] inputDir (label="Select folders", style="both")// only folder if possible
#@ String (choices={"Enter manually the set of parameters for each dataset", "Use one set of parameters for all the datasets (automatic scan dimensions)"}, style="radioButtonHorizontal") Choice_macro2

if(Choice_macro2=="Use one set of parameters for all the datasets (automatic scan dimensions)"){Use_one_set_of_parameters=true;}
if(Choice_macro2=="Enter manually the set of parameters for each dataset"){Use_one_set_of_parameters=false;}
umax=lengthOf(inputDir);
print("------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
Display_Version(Version);
print("\n                    Mode: "+Choice_macro+"   |   "+inputDir.length+" Dataset(s) \n ");

	print("------------------------------------------ Folders ------------------------------------------");
	
	for (u = 0; u < umax; u++) {
		inputDir[u] = Check_path__folder_name_replacer(inputDir[u]);
		print((u+1)+"  "+inputDir[u]);
	}

/////////////////////////////////////////////////////////////		DIALOGS			////////////////////////////////////////////////////////////////////////////////////////////////////



html = return_html_help();	//Help part

if (Choice_macro == "Registration") { Version = 15.1;
	print("---------------------------------------- Dimensions ----------------------------------------");

	line_length = 196; column_length = 4; // X, Y 
	Size_real = 0;
	image_size_default= 512; image_size= 512;
	step=1; // to open a fraction of the line only : set bigger for testing
	Bool_Binning_at_Opening		= true;
	Bool_Align_line 			= true; R_align	= 128; R_align_min= 30; divg_max= 0.1;
	Bool_Mean_scan 				= true; kernelsize=3;
	Bool_Background				= true; Background_size = 50;
	GB_list = newArray(0, 1, 2, 3, 4); GB_choice = "2.0";
	Bool_generate_preparation 	= false;
	Bool_Registration 			= true; prominence= 3; Radius_start= 10; nSpots_max= 150;
	Bool_Rename_image			= false; image_name = ""; Bool_Rename_image_auto	= false;
	
		line_length_ 				= newArray(umax);
		column_length_ 				= newArray(umax);
		Bool_Align_line_	 		= newArray(umax);
		Bool_Binning_at_Opening_	= newArray(umax);
		divg_max_					= newArray(umax);
		Bool_Mean_scan_ 			= newArray(umax);
		Bool_Background_ 			= newArray(umax);
		GB_choice_					= newArray(umax);
		Bool_generate_preparation_	= newArray(umax);
		Bool_Registration_			= newArray(umax);
		prominence_					= newArray(umax);
		Radius_start_				= newArray(umax);
		nSpots_max_					= newArray(umax);
		Bool_Rebuild_image_			= newArray(umax);
		image_size_default_			= newArray(umax);
		M_factor_ini_				= newArray(umax);
		R_factor_1_					= newArray(umax);
		R_factor_2_					= newArray(umax);
		Bool_Rename_image_			= newArray(umax);
		image_name_					= newArray(umax);
		Bool_Rename_image_auto_		= newArray(umax);
		

	for (u = 0; u < umax; u++) {
		if((u==0 && Use_one_set_of_parameters==true) || Use_one_set_of_parameters==false){
			print("   Counting files, wait for dialog...");
			filelist = getFileList(inputDir[u]);
			image_list = newArray(2); image_count = 0;
				for (i = 0; i < lengthOf(filelist); i++) {
				    if (endsWith(filelist[i], ".bmp")) { 
						image_list[image_count] = filelist[i];
				        image_count++;
				    } image_list = Array.trim(image_list, image_count);
				}		
		Size_real = lengthOf(image_list); Size = Find_X_Y_in_path(inputDir[u]);
		//print("----   "+File.getName(inputDir[u])+"   ----");
		print("\\Update:----   "+File.getName(inputDir[u])+" : ");
		Scan_size_solution = Correct_scan_size(Size[0], Size[1], Size_real, 250);  //// EXPERIMENTAL gives array(string message solution, solution X, solution Y)
		
		if(Use_one_set_of_parameters==false){Dialog.create("Options - Unique set of parameters for each dataset");}
		if(Use_one_set_of_parameters==true){Dialog.create("Options - Unique set of parameters for all datasets (! scan dimensions are automatic)");}
		Dialog.addHelp(html);
		
		Dialog.addMessage("---------------------------------------------------------  Scan title  ----------------------------------------------------------------", 13, "black");
		Dialog.addMessage(File.getName(inputDir[u]), 15, "blue");
		
		Dialog.addMessage("---------------------------------------------------------  Scan size  ----------------------------------------------------------------", 13, "black");
			if(indexOf(Scan_size_solution[0], "not") != -1){Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "red");} 
			else {Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "10b900");}
				Dialog.addNumber("X", Scan_size_solution[1]);
				Dialog.addNumber("Y", Scan_size_solution[2]);
		
		Dialog.addMessage("--------------------------------------------------------  Prepararation  --------------------------------------------------------------", 13, "black");
				Dialog.addCheckbox("Binning to 512*512 (Recommended)", Bool_Binning_at_Opening);
				Dialog.addCheckbox("Align_Stack_XmYm_Adaptative_V2", Bool_Align_line);
					Dialog.addToSameRow(); Dialog.addNumber("Divergence max", divg_max);
				Dialog.addCheckbox("Mean scan (3x3)", Bool_Mean_scan);
				Dialog.addCheckbox("Substract Background", Bool_Background);
				Dialog.addChoice("Gaussian Blur (px)", GB_list, GB_choice); Dialog.addToSameRow(); Dialog.addMessage("Spot positions accuracy++");
				Dialog.addCheckbox("Write images of preparation", Bool_generate_preparation);
					Dialog.addToSameRow(); Dialog.addString("Optional name : ", image_name);
					Dialog.addToSameRow(); Dialog.addCheckbox("Optional Auto rename", Bool_Rename_image_auto);
		Dialog.addMessage("--------------------------------------------------------  Registration  --------------------------------------------------------------", 13, "black");
				Dialog.addCheckbox("Spot Registration v15.1", Bool_Registration);
					Dialog.addNumber("Minimum Prominence", prominence);
					Dialog.addNumber("Radius_start", Radius_start);
					Dialog.addNumber("nSpots_max", nSpots_max);
		Dialog.show();
		line_length_[u] 				= Dialog.getNumber();
		column_length_[u] 				= Dialog.getNumber();
		Bool_Binning_at_Opening_[u] 	= Dialog.getCheckbox();
		Bool_Align_line_[u] 			= Dialog.getCheckbox();
		divg_max_[u]					= Dialog.getNumber();
		Bool_Mean_scan_[u] 				= Dialog.getCheckbox();
		Bool_Background_[u] 			= Dialog.getCheckbox();
		GB_choice_[u]					= parseInt(Dialog.getChoice());
		Bool_generate_preparation_[u]	= Dialog.getCheckbox();
			image_name_[u]				= Dialog.getString();
			Bool_Rename_image_auto_[u]	= Dialog.getCheckbox();
		Bool_Registration_[u]			= Dialog.getCheckbox();
		prominence_[u]					= Dialog.getNumber();
		Radius_start_[u]				= Dialog.getNumber();
		nSpots_max_[u]					= Dialog.getNumber();
		if (image_name_[u]=="") {Bool_Rename_image_[u]=1;}
		}
	
		if(Use_one_set_of_parameters==true && u>0){
			filelist = getFileList(inputDir[u]);
			image_list = newArray(2); image_count = 0;
				for (i = 0; i < lengthOf(filelist); i++) {
				    if (endsWith(filelist[i], ".bmp")) { 
						image_list[image_count] = filelist[i];
				        image_count++;
				    } image_list = Array.trim(image_list, image_count);
				}		
		Size_real = lengthOf(image_list); Size = Find_X_Y_in_path(inputDir[u]);
		//print("----   "+File.getName(inputDir[u])+"   ----");
		print("\\Update:----   "+File.getName(inputDir[u])+" : ");
		Scan_size_solution = Correct_scan_size(Size[0], Size[1], Size_real, 250); 
		
			line_length_[u] 				= Scan_size_solution[1];
			column_length_[u] 				= Scan_size_solution[2];
			Bool_Binning_at_Opening_[u] 	= Bool_Binning_at_Opening_[0];
			Bool_Align_line_[u] 			= Bool_Align_line_[0];
			divg_max_[u]					= divg_max_[0];
			Bool_Mean_scan_[u] 				= Bool_Mean_scan_[0];
			Bool_Background_[u] 			= Bool_Background_[0];
			GB_choice_[u]					= GB_choice_[0];
			Bool_generate_preparation_[u]	= Bool_generate_preparation_[0];
				image_name_[u]				= image_name_[0];
				Bool_Rename_image_auto_[u]	= Bool_Rename_image_auto_[0];
			Bool_Registration_[u]			= Bool_Registration_[0];
			prominence_[u]					= prominence_[0];
			Radius_start_[u]				= Radius_start_[0];
			nSpots_max_[u]					= nSpots_max_[0];
		}
	}
}

if (Choice_macro == "Reconstruction") { Version = 4.0;
	//print("Folder Process- Reconstruction from CSV \t Version "+Version);
	
	// Initialization																														// DEFAULT INPUT PARAMETERS 11/10/2022 GB to 0 intensity issue
	extension="";
	Bool_align_from_CSV = true;
	image_size_default= 512; image_size= 512; upsize = 4; GB = 0; R_factor_1= 4; R_factor_2= 2; M_factor_a = 1; M_factor_b = 0;
	Bool_no_reconstruction			= false;
	Bool_virtual_brightfield 		= true;
	Bool_full_virtual_brightfield 	= true;
	Bool_spot_count_map 			= true;
	Bool_StdDev_map 				= true;
	Bool_Prominence_min_map 		= true;
	Bool_pro_pseudo_map				= true;
	s = 0; X=0; Y=0;
	
		Bool_align_from_CSV_ 		= newArray(umax);
		upsize_						= newArray(umax);
		image_size_					= newArray(umax);
		R_factor_1_					= newArray(umax);
		R_factor_2_					= newArray(umax);
		GB_							= newArray(umax);
		Bool_no_reconstruction_		= newArray(umax);
		Bool_virtual_brightfield_ 		= newArray(umax);
		Bool_full_virtual_brightfield_ 	= newArray(umax);
		Bool_spot_count_map_ 			= newArray(umax);
		Bool_StdDev_map_ 				= newArray(umax);
		Bool_Prominence_min_map_ 		= newArray(umax);
		Bool_pro_pseudo_map_			= newArray(umax);
		
	//Dialog (nldr)
	for (u = 0; u < umax; u++) {	
		if((u==0 && Use_one_set_of_parameters==true) || Use_one_set_of_parameters==false){
		Dialog.create("Options");
		Dialog.addMessage("------------------------ Scan title ----------------------------");
		Dialog.addMessage(File.getName(inputDir[u]), 15, "blue");
		//Dialog.addMessage(Directory_name(inputDir[u]));
			
		Dialog.addMessage("-------------------- Reconstruction -----------------------");
			Dialog.addCheckbox("Refine alignment (0.001 px)", Bool_align_from_CSV); Dialog.addHelp(html);
			Dialog.addNumber("Building on ", upsize, 0, 4, "times larger images (enhance accuracy of spot positions)");	
			Dialog.addNumber("Ouput image size", image_size, 0, 4, "px");	
			 Dialog.addNumber("          Radius central spot", R_factor_1);
			 Dialog.addNumber("Radius spot", R_factor_2);
			 Dialog.addNumber("Gaussian Blur", GB);
		Dialog.addCheckbox("No reconstruction, build only maps:", Bool_no_reconstruction);
		Dialog.addCheckbox("Draw Virtual Brightfield", Bool_virtual_brightfield);
		Dialog.addCheckbox("Draw Full Virtual Brightfield", Bool_full_virtual_brightfield);
		Dialog.addCheckbox("Draw Spot Count map", Bool_spot_count_map);
		Dialog.addCheckbox("Draw Standard Deviation map", Bool_StdDev_map);
		Dialog.addCheckbox("Draw Minimum Prominence map", Bool_Prominence_min_map);
		Dialog.addCheckbox("Draw pseudo Prominence map", Bool_pro_pseudo_map);
		Dialog.show();	
		Bool_align_from_CSV_[u] 		= Dialog.getCheckbox();
		upsize_[u]						= Dialog.getNumber();
		image_size_[u]					= Dialog.getNumber();
		R_factor_1_[u]					= Dialog.getNumber();
		R_factor_2_[u]					= Dialog.getNumber();
		GB_[u]							= Dialog.getNumber();
		Bool_no_reconstruction_[u] 		= Dialog.getCheckbox();
		Bool_virtual_brightfield_[u] 		= Dialog.getCheckbox();
		Bool_full_virtual_brightfield_[u] 	= Dialog.getCheckbox();
		Bool_spot_count_map_[u] 			= Dialog.getCheckbox();
		Bool_StdDev_map_[u] 				= Dialog.getCheckbox();
		Bool_Prominence_min_map_[u] 		= Dialog.getCheckbox();
		Bool_pro_pseudo_map_[u] 			= Dialog.getCheckbox();
		}
		if(Use_one_set_of_parameters==true && u>0){
			Bool_align_from_CSV_[u] 		= Bool_align_from_CSV_[0];
			upsize_[u]						= upsize_[0];
			image_size_[u]					= image_size_[0];
			R_factor_1_[u]					= R_factor_1_[0];
			R_factor_2_[u]					= R_factor_2_[0];
			GB_[u]							= GB_[0];
			Bool_no_reconstruction_[u] 			= Bool_no_reconstruction_[0];
			Bool_virtual_brightfield_[u] 		= Bool_virtual_brightfield_[0];
			Bool_full_virtual_brightfield_[u] 	= Bool_full_virtual_brightfield_[0];
			Bool_spot_count_map_[u] 			= Bool_spot_count_map_[0];
			Bool_StdDev_map_[u] 				= Bool_StdDev_map_[0];
			Bool_Prominence_min_map_[u] 		= Bool_Prominence_min_map_[0];
			Bool_pro_pseudo_map_[u] 			= Bool_pro_pseudo_map_[0];
		}
	}
}
	
if (Choice_macro == "Registration+Reconstruction") {
		print("---------------------------------------- Dimensions ----------------------------------------");
	// Initialization
	line_length = 196; column_length = 4; // X, Y
	Size_real = 0;
	image_size_default= 512; image_size= 512;
	step=1; // to open a fraction of the line only : set bigger for testing
	Bool_Binning_at_Opening		= true;
	Bool_Align_line 			= false; R_align	= 128; R_align_min= 30; divg_max= 0.1;
	Bool_Mean_scan 				= false; kernelsize=3;
	Bool_Background				= true; Background_size = 50;
	GB_list = newArray(0, 1, 2, 3, 4); GB_choice = "2.0";
	Bool_generate_preparation 	= false;
	Bool_Registration 			= true; prominence= 3; Radius_start= 10; nSpots_max= 150;
	Bool_Rename_image			= false; image_name = ""; Bool_Rename_image_auto	= false;
	extension="";
	Bool_align_from_CSV = false;
	image_size_default= 512; upsize = 4; image_size= 512; GB = 0; R_factor_1= 6; R_factor_2= 4; M_factor_a = 1; M_factor_b = 0;
	Bool_no_reconstruction			= false;
	Bool_virtual_brightfield 		= true;
	Bool_full_virtual_brightfield 	= true;
	Bool_spot_count_map 			= true;
	Bool_StdDev_map 				= true;
	Bool_Prominence_min_map 		= true;
	Bool_pro_pseudo_map				= true;
	s = 0; X=0; Y=0;
	
		line_length_ 				= newArray(umax);
		column_length_ 				= newArray(umax);
		Bool_Align_line_	 		= newArray(umax);
		Bool_Binning_at_Opening_	= newArray(umax);
		divg_max_					= newArray(umax);
		Bool_Mean_scan_ 			= newArray(umax);
		Bool_Background_ 			= newArray(umax);
		GB_choice_					= newArray(umax);
		Bool_generate_preparation_	= newArray(umax);
		Bool_Registration_			= newArray(umax);
		prominence_					= newArray(umax);
		Radius_start_				= newArray(umax);
		nSpots_max_					= newArray(umax);
		Bool_Rebuild_image_			= newArray(umax);
		image_size_default_			= newArray(umax);
		M_factor_ini_				= newArray(umax);
		R_factor_1_					= newArray(umax);
		R_factor_2_					= newArray(umax);
		Bool_Rename_image_			= newArray(umax);
		image_name_					= newArray(umax);
		Bool_Rename_image_auto_		= newArray(umax);
		
		output_						= newArray(umax);
		
		Bool_align_from_CSV_ 			= newArray(umax);
		upsize_							= newArray(umax);
		image_size_						= newArray(umax);
		R_factor_1_						= newArray(umax);
		R_factor_2_						= newArray(umax);
		GB_								= newArray(umax);
		Bool_no_reconstruction_			= newArray(umax);
		Bool_virtual_brightfield_ 		= newArray(umax);
		Bool_full_virtual_brightfield_ 	= newArray(umax);
		Bool_spot_count_map_ 			= newArray(umax);
		Bool_StdDev_map_ 				= newArray(umax);
		Bool_Prominence_min_map_ 		= newArray(umax);
		Bool_pro_pseudo_map_			= newArray(umax);
		
	for (u = 0; u < umax; u++) {
		if((u==0 && Use_one_set_of_parameters==true) || Use_one_set_of_parameters==false){
		print("   Counting files, wait for dialog...");
			filelist = getFileList(inputDir[u]);
			image_list = newArray(2); image_count = 0;
				for (i = 0; i < lengthOf(filelist); i++) {
				    if (endsWith(filelist[i], ".bmp")) { 
						image_list[image_count] = filelist[i];
				        image_count++;
				    } image_list = Array.trim(image_list, image_count);
				}
			Size_real = lengthOf(image_list); Size = Find_X_Y_in_path(inputDir[u]);
		//print("----   "+File.getName(inputDir[u])+"   ----");
		print("\\Update:----   "+File.getName(inputDir[u])+" : ");
		Scan_size_solution = Correct_scan_size(Size[0], Size[1], Size_real, 250);  //// EXPERIMENTAL gives array(string message solution, solution X, solution Y)
		if(Use_one_set_of_parameters==false){Dialog.create("Options - Unique set of parameters for each dataset");}
		if(Use_one_set_of_parameters==true){Dialog.create("Options - Unique set of parameters for all datasets (! scan dimensions are automatic)");}
		Dialog.addHelp(html);
		Dialog.addMessage("--------------------------------------------------------------- Scan --------------------------------------------------------------------", 13, "black");
		Dialog.addMessage(File.getName(inputDir[u]), 15, "blue");
		Dialog.addMessage("--------------------------------------------------------- Size of Scan  ----------------------------------------------------------------", 13, "black");
			if(indexOf(Scan_size_solution[0], "not") != -1){Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "red");} 
			else {Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "10b900");}
				Dialog.addNumber("X", Scan_size_solution[1]);
				Dialog.addNumber("Y", Scan_size_solution[2]);
		Dialog.addMessage("-------------------------------------------------------  Prepararation  ----------------------------------------------------------------", 13, "black");
				Dialog.addCheckbox("Binning to 512*512 (Recommended)", Bool_Binning_at_Opening);
				Dialog.addCheckbox("Align_Stack_XmYm_Adaptative_V2", Bool_Align_line);
					Dialog.addToSameRow(); Dialog.addNumber("Divergence max", divg_max);
				Dialog.addCheckbox("Mean scan (3x3)", Bool_Mean_scan);
				Dialog.addCheckbox("Substract Background", Bool_Background);
				
				Dialog.addChoice("Gaussian Blur (px)", GB_list, GB_choice); Dialog.addToSameRow(); Dialog.addMessage("Spot positions accuracy++");
				Dialog.addCheckbox("Write images of preparation", Bool_generate_preparation);
					Dialog.addToSameRow(); Dialog.addString("Optional name : ", image_name);
					Dialog.addToSameRow(); Dialog.addCheckbox("Optional Auto rename", Bool_Rename_image_auto);
		Dialog.addMessage("--------------------------------------------------------  Registration  --------------------------------------------------------------", 13, "black");
				//Dialog.addCheckbox("Spot Registration V6", Bool_Registration);
					//Dialog.addToSameRow(); 
					Dialog.addNumber("Minimum Prominence", prominence); Dialog.addToSameRow(); Dialog.addMessage("(prominence > standard deviation)");
					Dialog.addNumber("Radius_start", Radius_start); 	Dialog.addToSameRow(); Dialog.addMessage("(px) < distance between 2 spots");
					Dialog.addNumber("nSpots_max", nSpots_max);
		Dialog.addMessage("------------------------------------------------------  Reconstruction  -----------------------------------------------------------", 13, "black");
			Dialog.addCheckbox("Refine alignment (0.001 px)", Bool_align_from_CSV);
			Dialog.addNumber("Building on ", upsize, 0, 4, "times larger images"); Dialog.addToSameRow(); Dialog.addMessage("Enhance accuracy of spot positions");			Dialog.addNumber("Ouput image size", image_size, 0, 4, "px");	
			 Dialog.addNumber("         Radius central spot", R_factor_1);
			 Dialog.addNumber("Radius spot", R_factor_2);
			 Dialog.addNumber("Gaussian Blur", GB); Dialog.addToSameRow(); Dialog.addMessage("Applied on final render");
		Dialog.addCheckbox("No reconstruction, only build maps:", Bool_no_reconstruction);
		Dialog.addCheckbox("Draw Virtual Brightfield", Bool_virtual_brightfield);
		Dialog.addCheckbox("Draw Full Virtual Brightfield", Bool_full_virtual_brightfield);
		Dialog.addCheckbox("Draw Spot Count map", Bool_spot_count_map);
		Dialog.addCheckbox("Draw Standard Deviation map", Bool_StdDev_map);
		Dialog.addCheckbox("Draw Minimum Prominence map", Bool_Prominence_min_map);
		Dialog.addCheckbox("Draw pseudo Prominence map", Bool_pro_pseudo_map);
		Dialog.show();
		line_length_[u] 				= Dialog.getNumber();
		column_length_[u] 				= Dialog.getNumber();
		Bool_Binning_at_Opening_[u] 	= Dialog.getCheckbox();
		Bool_Align_line_[u] 			= Dialog.getCheckbox();
		divg_max_[u]					= Dialog.getNumber();
		Bool_Mean_scan_[u] 				= Dialog.getCheckbox();
		Bool_Background_[u] 			= Dialog.getCheckbox();
		GB_choice_[u]					= parseInt(Dialog.getChoice());
		Bool_generate_preparation_[u]	= Dialog.getCheckbox();
			image_name_[u]				= Dialog.getString();
			Bool_Rename_image_auto_[u]	= Dialog.getCheckbox();
		//Bool_Registration_[u]			= Dialog.getCheckbox();
		prominence_[u]					= Dialog.getNumber();
		Radius_start_[u]				= Dialog.getNumber();
		nSpots_max_[u]					= Dialog.getNumber();
		if (image_name_[u]=="") {Bool_Rename_image_[u]=1;}
		Bool_align_from_CSV_[u] 		= Dialog.getCheckbox();
		upsize_[u]						= Dialog.getNumber();
		image_size_[u]					= Dialog.getNumber();
		R_factor_1_[u]					= Dialog.getNumber();
		R_factor_2_[u]					= Dialog.getNumber();
		GB_[u]							= Dialog.getNumber();
		Bool_no_reconstruction_[u]			= Dialog.getCheckbox();
		Bool_virtual_brightfield_[u] 		= Dialog.getCheckbox();
		Bool_full_virtual_brightfield_[u] 	= Dialog.getCheckbox();
		Bool_spot_count_map_[u] 			= Dialog.getCheckbox();
		Bool_StdDev_map_[u] 				= Dialog.getCheckbox();
		Bool_Prominence_min_map_[u] 		= Dialog.getCheckbox();
		Bool_pro_pseudo_map_[u]				= Dialog.getCheckbox();
		}
		if(Use_one_set_of_parameters==true && u>0){
			filelist = getFileList(inputDir[u]);
			image_list = newArray(2); image_count = 0;
				for (i = 0; i < lengthOf(filelist); i++) {
				    if (endsWith(filelist[i], ".bmp")) { 
						image_list[image_count] = filelist[i];
				        image_count++;
				    } image_list = Array.trim(image_list, image_count);
				}
			Size_real = lengthOf(image_list); Size = Find_X_Y_in_path(inputDir[u]);
			print("\\Update:----   "+File.getName(inputDir[u])+" : ");
			Scan_size_solution = Correct_scan_size(Size[0], Size[1], Size_real, 250);
				line_length_[u] 				= Scan_size_solution[1];
				column_length_[u] 				= Scan_size_solution[2];
				Bool_Binning_at_Opening_[u] 	= Bool_Binning_at_Opening_[0];
				Bool_Align_line_[u] 			= Bool_Align_line_[0];
				divg_max_[u]					= divg_max_[0];
				Bool_Mean_scan_[u] 				= Bool_Mean_scan_[0];
				Bool_Background_[u] 			= Bool_Background_[0];
				GB_choice_[u]					= GB_choice_[0];
				Bool_generate_preparation_[u]	= Bool_generate_preparation_[0];
					image_name_[u]				= image_name_[0];	
					Bool_Rename_image_auto_[u]	= Bool_Rename_image_auto_[0];
				prominence_[u]					= prominence_[0];	
				Radius_start_[u]				= Radius_start_[0];	
				nSpots_max_[u]					= nSpots_max_[0];	
				if (image_name_[u]=="") {Bool_Rename_image_[0]=1;}
				Bool_align_from_CSV_[u] 		= Bool_align_from_CSV_[0];
				upsize_[u]						= upsize_[0];	
				image_size_[u]					= image_size_[0];
				R_factor_1_[u]					= R_factor_1_[0];		
				R_factor_2_[u]					= R_factor_2_[0];		
				GB_[u]							= GB_[0];	
				Bool_no_reconstruction_[u]			= Bool_no_reconstruction_[0];	
				Bool_virtual_brightfield_[u] 		= Bool_virtual_brightfield_[0] ;
				Bool_full_virtual_brightfield_[u] 	= Bool_full_virtual_brightfield_[0];
				Bool_spot_count_map_[u] 			= Bool_spot_count_map_[0];
				Bool_StdDev_map_[u] 				= Bool_StdDev_map_[0];
				Bool_Prominence_min_map_[u] 		= Bool_Prominence_min_map_[0];
				Bool_pro_pseudo_map_[u]				= Bool_pro_pseudo_map_[0];
		}
	}
}

if (Choice_macro == "Reg+Rec_Rapid") {
		print("---------------------------------------- Dimensions ----------------------------------------");
	// Initialization
	line_length = 196; column_length = 4; // X, Y
	Size_real = 0;
	image_size_default= 512; image_size= 512;
	step=1; // to open a fraction of the line only : set bigger for testing
	Bool_Binning_at_Opening		= true;
	Bool_Align_line 			= false; R_align	= 128; R_align_min= 30; divg_max= 0.1;
	Bool_Mean_scan 				= false; kernelsize=3;
	Bool_Background				= true; Background_size = 50;
	GB_list = newArray(0, 1, 2, 3, 4); GB_choice = GB_list[2];
	Bool_generate_preparation 	= false;
	Bool_Registration 			= true; prominence= 3; Radius_start= 10; Radius_final=3; nSpots_max= 150;
	Bool_Spot_radius_fixed		= true;
	Bool_Rename_image			= false; image_name = ""; Bool_Rename_image_auto	= false;
	extension="";
	Bool_align_from_CSV = false;
	image_size_default= 512; upsize = 4; image_size= 512; GB = 0; R_factor_1= 4; R_factor_2= 2; M_factor_a = 1; M_factor_b = 0;
	Bool_virtual_brightfield = true;
	s = 0; X=0; Y=0;
	
		line_length_ 				= newArray(umax);
		column_length_ 				= newArray(umax);
		Bool_Align_line_	 		= newArray(umax);
		Bool_Binning_at_Opening_	= newArray(umax);
		divg_max_					= newArray(umax);
		Bool_Mean_scan_ 			= newArray(umax);
		Bool_Background_ 			= newArray(umax);
		GB_choice_					= newArray(umax);
		Bool_generate_preparation_	= newArray(umax);
		Bool_Registration_			= newArray(umax);
		prominence_					= newArray(umax);
		Bool_Spot_radius_fixed_		= newArray(umax);
		Radius_start_				= newArray(umax);
		Radius_final_				= newArray(umax);
		nSpots_max_					= newArray(umax);
		Bool_Rebuild_image_			= newArray(umax);
		upsize_						= newArray(umax);
		image_size_default_			= newArray(umax);
		M_factor_ini_				= newArray(umax);
		R_factor_1_					= newArray(umax);
		R_factor_2_					= newArray(umax);
		Bool_Rename_image_			= newArray(umax);
		image_name_					= newArray(umax);
		Bool_Rename_image_auto_		= newArray(umax);
		
		output_						= newArray(umax);
		
		Bool_align_from_CSV_ 		= newArray(umax);
		image_size_					= newArray(umax);
		R_factor_1_					= newArray(umax);
		R_factor_2_					= newArray(umax);
		GB_							= newArray(umax);
		Bool_virtual_brightfield_ 	= newArray(umax);
		
	for (u = 0; u < umax; u++) {
		print("   Counting files, wait for dialog...");
			filelist = getFileList(inputDir[u]);
			image_list = newArray(2); image_count = 0;
				for (i = 0; i < lengthOf(filelist); i++) {
				    if (endsWith(filelist[i], ".bmp")) { 
						image_list[image_count] = filelist[i];
				        image_count++;
				    } image_list = Array.trim(image_list, image_count);
				}
			Size_real = lengthOf(image_list); Size = Find_X_Y_in_path(inputDir[u]);
		//print("----   "+File.getName(inputDir[u])+"   ----");
		print("\\Update:----   "+File.getName(inputDir[u])+" : ");
		Scan_size_solution = Correct_scan_size(Size[0], Size[1], Size_real, 250);  //// EXPERIMENTAL gives array(string message solution, solution X, solution Y)
		Dialog.create("Options - 1 set of parameters for each dataset");
		Dialog.addHelp(html);
		Dialog.addMessage("--------------------------------------------------------------- Scan --------------------------------------------------------------------", 13, "black");
		Dialog.addMessage(File.getName(inputDir[u]), 15, "blue");
		Dialog.addMessage("--------------------------------------------------------- Size of Scan  ----------------------------------------------------------------", 13, "black");
			if(indexOf(Scan_size_solution[0], "not") != -1){Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "red");} 
			else {Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "10b900");}
				Dialog.addNumber("X", Scan_size_solution[1]);
				Dialog.addNumber("Y", Scan_size_solution[2]);
		Dialog.addMessage("-------------------------------------------------------  Prepararation  ----------------------------------------------------------------", 13, "black");
				Dialog.addCheckbox("Binning to 512*512 (Recommended)", Bool_Binning_at_Opening);
				Dialog.addCheckbox("Align_Stack_XmYm_Adaptative_V2", Bool_Align_line);
					Dialog.addToSameRow(); Dialog.addNumber("Divergence max", divg_max);
				Dialog.addCheckbox("Mean scan (3x3)", Bool_Mean_scan);
				Dialog.addCheckbox("Substract Background", Bool_Background);
				
				Dialog.addChoice("Gaussian Blur (px)", GB_list, "2.0"); Dialog.addToSameRow(); Dialog.addMessage("Gaussian Blur (spot positions accuracy++)");
				
				Dialog.addCheckbox("Write images of preparation", Bool_generate_preparation);
					Dialog.addToSameRow(); Dialog.addString("Optional name : ", image_name);
					Dialog.addToSameRow(); Dialog.addCheckbox("Optional Auto rename", Bool_Rename_image_auto);
		Dialog.addMessage("--------------------------------------------------------  Registration  --------------------------------------------------------------", 13, "black");
				//Dialog.addCheckbox("Spot Registration V6", Bool_Registration);
					//Dialog.addToSameRow(); 
					Dialog.addNumber("Prominence", prominence);
					Dialog.addCheckbox("Rapid Reg+Rec", Bool_Spot_radius_fixed);
					Dialog.addNumber("Radius_start", Radius_start);
					Dialog.addNumber("Radius_final", Radius_final);
					Dialog.addNumber("nSpots_max", nSpots_max);
		Dialog.addMessage("------------------------------------------------------  Reconstruction  -----------------------------------------------------------", 13, "black");
			Dialog.addCheckbox("Refine alignment (0.001 px)", Bool_align_from_CSV);
			Dialog.addNumber("Building image size", upsize, 0, 4, "px (accuracy)");	
			Dialog.addNumber("Ouput image size", image_size, 0, 4, "px");	
			 Dialog.addNumber("         Radius central spot", R_factor_1);
			 Dialog.addNumber("Radius spot", R_factor_2);
			 Dialog.addNumber("Gaussian Blur", GB); Dialog.addToSameRow(); Dialog.addMessage("Applied on final render");
			 Dialog.addToSameRow();Dialog.addMessage("Note: V"+Version+": Intensities corrected when GB = (0, 1)", 12, "black");
		Dialog.addCheckbox("Draw Virtual Brightfield (Full)", Bool_virtual_brightfield);
		Dialog.show();
		line_length_[u] 				= Dialog.getNumber();
		column_length_[u] 				= Dialog.getNumber();
		Bool_Binning_at_Opening_[u] 	= Dialog.getCheckbox();
		Bool_Align_line_[u] 			= Dialog.getCheckbox();
		divg_max_[u]					= Dialog.getNumber();
		Bool_Mean_scan_[u] 				= Dialog.getCheckbox();
		Bool_Background_[u] 			= Dialog.getCheckbox();
		GB_choice_[u]					= parseInt(Dialog.getChoice());
		Bool_generate_preparation_[u]	= Dialog.getCheckbox();
			image_name_[u]				= Dialog.getString();
			Bool_Rename_image_auto_[u]	= Dialog.getCheckbox();
		//Bool_Registration_[u]			= Dialog.getCheckbox();
		prominence_[u]					= Dialog.getNumber();
		Bool_Spot_radius_fixed_[u] 		= Dialog.getCheckbox();
		Radius_start_[u]				= Dialog.getNumber();
		Radius_final_[u]				= Dialog.getNumber();
		nSpots_max_[u]					= Dialog.getNumber();
		if (image_name_[u]=="") {Bool_Rename_image_[u]=1;}
		Bool_align_from_CSV_[u] 		= Dialog.getCheckbox();
		upsize_[u]						= Dialog.getNumber();
		image_size_[u]					= Dialog.getNumber();
		R_factor_1_[u]					= Dialog.getNumber();
		R_factor_2_[u]					= Dialog.getNumber();
		GB_[u]							= Dialog.getNumber();
		Bool_virtual_brightfield_[u] 	= Dialog.getCheckbox();
	}
}

if (Choice_macro == "Mask no-background data") {
		print("---------------------------------------- Dimensions ----------------------------------------");
	// Initialization
	line_length = 196; column_length = 4; // X, Y
	Size_real = 0;
	image_size_default= 512; image_size= 512;
	step=1; // to open a fraction of the line only : set bigger for testing
	Bool_Binning_at_Opening		= false;
	Bool_Align_line 			= false; R_align	= 128; R_align_min= 30; divg_max= 0.1;
	Bool_Mean_scan 				= false; kernelsize=3;
	Bool_Background				= true; Background_size = 50;
	Bool_generate_preparation 	= true;
	Bool_Registration 			= true; prominence= 3; Radius_start= 10; nSpots_max= 150;
	Bool_Rename_image			= false; image_name = ""; Bool_Rename_image_auto	= false;
	extension="";
	Bool_align_from_CSV = true;
	image_size_default= 512; upsize = 4; image_size= 512; GB = 2; R_factor_1= 4; R_factor_2= 2; M_factor_a = 1; M_factor_b = 0;
	Bool_virtual_brightfield = true;
	s = 0; X=0; Y=0;
	
		line_length_ 				= newArray(umax);
		column_length_ 				= newArray(umax);
		Bool_Align_line_	 		= newArray(umax);
		Bool_Binning_at_Opening_	= newArray(umax);
		divg_max_					= newArray(umax);
		Bool_Mean_scan_ 			= newArray(umax);
		Bool_Background_ 			= newArray(umax);
		prominence_					= newArray(umax);
		nSpots_max_					= newArray(umax);
		image_size_default_			= newArray(umax);
		output_						= newArray(umax);
		GB_							= newArray(umax);
		upsize_					= newArray(umax);
		image_size_					= newArray(umax);
	
	for (u = 0; u < umax; u++) {
		print("   Counting files, wait for dialog...");
			filelist = getFileList(inputDir[u]);
			image_list = newArray(2); image_count = 0;
				for (i = 0; i < lengthOf(filelist); i++) {
				    if (endsWith(filelist[i], ".bmp")) { 
						image_list[image_count] = filelist[i];
				        image_count++;
				    } image_list = Array.trim(image_list, image_count);
				}
			Size_real = lengthOf(image_list); Size = Find_X_Y_in_path(inputDir[u]);
		//print("----   "+File.getName(inputDir[u])+"   ----");
		print("\\Update:----   "+File.getName(inputDir[u])+" : ");
		Scan_size_solution = Correct_scan_size(Size[0], Size[1], Size_real, 250);  //// EXPERIMENTAL gives array(string message solution, solution X, solution Y)
		Dialog.create("Options - 1 set of parameters for each dataset");
		Dialog.addHelp(html);
		Dialog.addMessage("--------------------------------------------------------------- Scan --------------------------------------------------------------------", 13, "black");
		Dialog.addMessage(File.getName(inputDir[u]), 15, "blue");
		Dialog.addMessage("--------------------------------------------------------- Size of Scan  ----------------------------------------------------------------", 13, "black");
			if(indexOf(Scan_size_solution[0], "not") != -1){Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "red");} 
			else {Dialog.addMessage("Stack size"+" ("+Size[0]+"*"+Size[1]+"="+(Size[0]*Size[1])+", total in folder : "+Size_real+")"+"\n"+Scan_size_solution[0], 12, "10b900");}
				Dialog.addNumber("X", Scan_size_solution[1]);
				Dialog.addNumber("Y", Scan_size_solution[2]);
		Dialog.addMessage("-------------------------------------------------------  Mask  ----------------------------------------------------------------", 13, "black");
				Dialog.addCheckbox("Binning to 512*512 (Recommended)", Bool_Binning_at_Opening);
				Dialog.addCheckbox("Align_Stack_XmYm_Adaptative_V2", Bool_Align_line); Dialog.addToSameRow(); Dialog.addNumber("Divergence max", divg_max);
				Dialog.addCheckbox("Mean scan (3x3)", Bool_Mean_scan);
				Dialog.addCheckbox("Substract Background", Bool_Background);		
				Dialog.addNumber("Prominence", prominence);
				Dialog.addNumber("Gaussian Blur", GB); Dialog.addToSameRow(); Dialog.addMessage("Applied on final render");
				Dialog.addNumber("Building image size", upsize, 0, 4, "px (accuracy)");
				Dialog.addNumber("Ouput image size", image_size, 0, 4, "px");	
			 

		Dialog.show();
		line_length_[u] 				= Dialog.getNumber();
		column_length_[u] 				= Dialog.getNumber();
		Bool_Binning_at_Opening_[u] 	= Dialog.getCheckbox();
		Bool_Align_line_[u] 			= Dialog.getCheckbox();
		divg_max_[u]					= Dialog.getNumber();
		Bool_Mean_scan_[u] 				= Dialog.getCheckbox();
		Bool_Background_[u] 			= Dialog.getCheckbox();
		prominence_[u]					= Dialog.getNumber();
		GB_[u]							= Dialog.getNumber();
		upsize_[u]						= Dialog.getNumber();
		image_size_[u]					= Dialog.getNumber();

	}
}



/////////////////////////////////////////////////////////  STARTING TREATMENT  /////////////////////////////////////////////////////////////////////////////////////////////////

Work_time = getTime(); Date_1 = Date_Express(); 
if (Choice_macro == "Registration" || Choice_macro=="Registration+Reconstruction") {
	total_images = 0;
	total_images_ = newArray(umax);
		for (u = 0; u < umax; u++) {	
			if(u==0) {total_images_[u] = 0;}
			else{total_images_[u] = total_images_[u-1] + line_length_[u]*column_length_[u];}
		      total_images += line_length_[u]*column_length_[u];
		}
	print("Total number of images to treat : "+total_images+" (over "+umax+" datasets)");
}


/////////////////////////////////////////////////////////////	MASKING 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	MASKING 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	MASKING 	////////////////////////////////////////////////////////////////////////////////////////////////////

if (Choice_macro == "Mask no-background data") { Version = 14.0;
	print(" \n---------------------------------------- Masking ----------------------------------------");
	eval("js","IJ.getInstance().setSize(new Dimension(480, 60))"); 
	//eval("js","rm = RoiManager.getInstance2();rm.setVisible(false);");
	setBatchMode("hide"); 
	

	
	//loop for each folder
	for (u = 0; u < umax; u++) {
		print("----   "+File.getName(inputDir[u])+" : ");
		line_length 				= line_length_[u];
		column_length 				= column_length_[u];
		Bool_Binning_at_Opening     = Bool_Binning_at_Opening_[u];
		Bool_Align_line 			= Bool_Align_line_[u];
		divg_max					= divg_max_[u];
		Bool_Mean_scan				= Bool_Mean_scan_[u];
		Bool_Background				= Bool_Background_[u];
		prominence					= prominence_[u];
		GB 							= GB_[u];
		image_size					= image_size_[u];
		if(Bool_Background == 0) {Background_size =0;}
	
		extension = ""; extension = extension+"_Dim(0-"+column_length+",0-"+line_length+")";
						extension = extension+"_Mask_Pr["+prominence+"]"+"Gb["+GB+"]";
						if(Bool_Align_line == 1) {extension = extension+"_Al["+remove_comma_in_string_of_number(divg_max)+"]";}
						if(Bool_Mean_scan == 1) {extension = extension+"_Mean["+kernelsize+"]";}
						if(Bool_Background == 1) {extension = extension+"_Bg["+Background_size+"]";}	
						
						
		directory = inputDir[u];
		WorkDir= File.getParent(directory);
		namefolder = "randomstring";
		namefolder = File.getName(directory);
		output= File.makeDirectory(WorkDir+"\\"+namefolder+extension);
		output=WorkDir+"\\"+namefolder+extension;		
		
		//print("   Start Spots Registration by lines method (Version "+Version+") \n   "+directory+" \n   "+"Options"+extension+" \n   Scan size used : X= "+line_length+", Y= "+column_length+" \n   [dataset "+u+1+"/"+umax+"] Registration...");
		print("   "+directory+" \n   "+"Options"+extension+" \n   Scan size used : X= "+line_length+", Y= "+column_length+" \n   [dataset "+u+1+"/"+umax+"] Masking...");
		t0=getTime(); 
	
		for (i = 0; i < column_length; i++) {
				t1=getTime();
	
			//open useful lines / alignment included
				if(isOpen("line_"+i) != 1) { open_line(i); 
					if(Bool_Binning_at_Opening == 1) {run("Size...", "width=512 height=512 depth="+nSlices+" constrain average interpolation=Bilinear");}
					if(Bool_Align_line == 1) {Align_Stack_XmYm_Adaptative_V2(divg_max);}}
					
				if(isOpen("line_"+(i+1)) != 1 && i != column_length-1) { open_line(i+1); 
					if(Bool_Binning_at_Opening == 1) {run("Size...", "width=512 height=512 depth="+nSlices+" constrain average interpolation=Bilinear");}
					if(Bool_Align_line == 1) {Align_Stack_XmYm_Adaptative_V2(divg_max);}}
				
			//mean of the lines around line i, the function takes the border in account //mean along the line
				if(Bool_Mean_scan == 1) {Mean_line(i); Mean_stack_k3();	}
				
			//Substract Background
				if(Bool_Background == 1) {Background_size = getWidth/10; run("Subtract Background...", "rolling="+Background_size+" sliding stack");}
				
			//Masking here
				Find_spot_Mask_SubBGdata(Background_size, GB, prominence);		
			
			//rename slices
				for (k = 1; k <= nSlices; k++) {setSlice(k); run("Set Label...", "label="+IJ.pad(i, 4)+"-"+IJ.pad(k, 4));}
			
			//resize slices
				run("Size...", "width="+image_size+" height="+image_size+" depth="+nSlices+" constrain average interpolation=Bilinear");
				
			//save as images
				if(Bool_generate_preparation == 1) {run("Image Sequence... ", "select="+output+" dir="+output+" format=BMP name=name use");}
					
			//close useless line/stacks
				if(isOpen("line_"+(i-1)) == 1) { close("line_"+(i-1)); }
				if(isOpen("Mean_line_"+i) == 1) { close("Mean_line_"+i); }
				if(isOpen("line_"+(i-1)) == 1) { close("Result_line"+i); }
				//close("Mean_line_"+i); close("Result_line"+i);
			
			t2=getTime();
			print("\\Update:   [dataset "+u+1+"/"+umax+"]"+"[line "+i+1+" / "+column_length+"] \n [Time left : "+Time_express_V2((column_length-1-i)*(t2-t1))+" (estimation)]");
		
		}
		// close all
			close("*"); close(Table.title);
			print("   Preparation/Registration time: "+Time_express_V2(t2-t0)); 
	}
setBatchMode("exit and display");
eval("js","IJ.getInstance().setSize(new Dimension(600, 120))");
}
/////////////////////////////////////////////////////////////	REGISTRATION 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	REGISTRATION 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	REGISTRATION 	////////////////////////////////////////////////////////////////////////////////////////////////////

if (Choice_macro == "Registration" || Choice_macro=="Registration+Reconstruction") { Version = 14.0;
	print(" \n---------------------------------------- Registration ----------------------------------------");
	eval("js","IJ.getInstance().setSize(new Dimension(480, 60))");
	setBatchMode("hide"); 
	

	
	//loop for each folder
	for (u = 0; u < umax; u++) {											
		print("----   "+File.getName(inputDir[u])+" : ");
		line_length 				= line_length_[u];
		column_length 				= column_length_[u];
		Bool_Binning_at_Opening     = Bool_Binning_at_Opening_[u];
		Bool_Align_line 			= Bool_Align_line_[u];
		divg_max					= divg_max_[u];
		Bool_Mean_scan				= Bool_Mean_scan_[u];
		Bool_Background				= Bool_Background_[u];
		GB_choice					= GB_choice_[u];
		Bool_generate_preparation	= Bool_generate_preparation_[u];
		//Bool_Registration			= Bool_Registration_[u];
		prominence					= prominence_[u];
		Radius_start				= Radius_start_[u];
		nSpots_max					= nSpots_max_[u];
		
		Bool_Rename_image			= Bool_Rename_image_[u];
		image_name					= image_name_[u];
		Bool_Rename_image_auto		= Bool_Rename_image_auto_[u];
	
		extension = ""; extension = extension+"_Dim(0-"+column_length+",0-"+line_length+")";
						if(Bool_Align_line == 1) {extension = extension+"_Al["+remove_comma_in_string_of_number(divg_max)+"]";}
						if(Bool_Mean_scan == 1) {extension = extension+"_Mean["+kernelsize+"]";}
						if(Bool_Background == 1) {extension = extension+"_Bg["+Background_size+"]";}
						if(Bool_Registration == 1) {extension = extension+"_Reg["+prominence+"]"+"["+Radius_start+"]"+"["+nSpots_max+"]";}				
						
		directory = inputDir[u];
		parent= File.getParent(directory);
		namefolder = "randomstring";
		namefolder = File.getName(directory);
		File.makeDirectory(parent + File.separator + namefolder + extension);
		output= File.makeDirectory(parent + File.separator + namefolder + extension);
		output= parent + File.separator + namefolder + extension;
		
/* !! */	if (Choice_macro=="Registration+Reconstruction") {output_[u]=output;}
		
		
		//print("   Start Spots Registration by lines method (Version "+Version+") \n   "+directory+" \n   "+"Options"+extension+" \n   Scan size used : X= "+line_length+", Y= "+column_length+" \n   [dataset "+u+1+"/"+umax+"] Registration...");
		print("   "+directory+" \n   "+"Options"+extension+" \n   Scan size used : X= "+line_length+", Y= "+column_length+" \n   [dataset "+u+1+"/"+umax+"] Registration...");
		t0=getTime(); 
	
		for (i = 0; i < column_length; i++) {
				t1=getTime();
			
			t_Open=getTime();
			//open useful lines / alignment included
			if(Bool_Mean_scan == 1) {
				if(isOpen("line_"+i) != 1) { open_line(i); 
					if(Bool_Binning_at_Opening == 1) {run("Size...", "width=512 height=512 depth="+nSlices+" constrain average interpolation=Bilinear");}
					if(Bool_Align_line == 1) {Align_Stack_XmYm_Adaptative_V2(divg_max);}}
					
				if(isOpen("line_"+(i+1)) != 1 && i != column_length-1) { open_line(i+1); 
					if(Bool_Binning_at_Opening == 1) {run("Size...", "width=512 height=512 depth="+nSlices+" constrain average interpolation=Bilinear");}
					if(Bool_Align_line == 1) {Align_Stack_XmYm_Adaptative_V2(divg_max);}}
			t_Open=getTime()-t_Open;
			}
			if(Bool_Mean_scan != 1) {
				if(isOpen("line_"+i) != 1) { open_line(i); 
					if(Bool_Binning_at_Opening == 1) {run("Size...", "width=512 height=512 depth="+nSlices+" constrain average interpolation=Bilinear");}
					if(Bool_Align_line == 1) {Align_Stack_XmYm_Adaptative_V2(divg_max);}}
			}
				
			//mean of the lines around line i, the function takes the border in account //mean along the line
				if(Bool_Mean_scan == 1) {Mean_line(i); Mean_stack_k3();	}

			//Substract Background
				//if(Bool_Background == 1) {Background_size = getWidth/10; run("Subtract Background...", "rolling="+Background_size+" sliding stack");}
				
			t_Reg=getTime();
			//Registration here
				if(Bool_Registration == 1) {title = Spot_registration_2_stacks_pos_int_adaptative_prominence_V2(Bool_Background, prominence, Radius_start, nSpots_max, i, GB_choice);}		
				//if(Bool_Registration == 1) {title = Spot_registration_stack_V6(prominence, Radius_start, nSpots_max, i, GB_choice);}	
			t_Reg=getTime()-t_Reg;
			
			t_Ren=getTime();
			//rename slices
				if(Bool_Rename_image_auto == 1) {image_name = namefolder+extension;}
				if(Bool_Rename_image == 1 || Bool_Rename_image_auto == 1) {for (k = 1; k <= nSlices; k++) {setSlice(k); run("Set Label...", "label="+image_name+"_"+IJ.pad(i, 4)+"-"+IJ.pad(k, 4));}}
				if(Bool_Rename_image == 0 && Bool_Rename_image_auto == 0) {for (k = 1; k <= nSlices; k++) {setSlice(k); run("Set Label...", "label="+IJ.pad(i, 4)+"-"+IJ.pad(k, 4));}}
			t_Ren=getTime()-t_Ren;
			
			t_Write=getTime();
			//save as images
				if(Bool_generate_preparation == 1) {run("Image Sequence... ", "select="+output+" dir="+output+" format=BMP name=name use");}
						
			//close useless line/stacks
				if(isOpen("line_"+(i-1)) == 1) { close("line_"+(i-1)); }
				if(isOpen("Mean_line_"+i) == 1) { close("Mean_line_"+i); }
				if(isOpen("line_"+(i-1)) == 1) { close("Result_line"+i); }
				//close("Mean_line_"+i); close("Result_line"+i);
			t_Write=getTime()-t_Write;	
			
			t2=getTime();
			//total_images_[u]+(i+1)*line_length;
			print("\\Update:   [dataset "+u+1+"/"+umax+"]"+"[line "+i+1+" / "+column_length+"] \n [Time left : "+Time_express_V2((column_length-1-i)*(t2-t1))+"] \n ["+total_images_[u]+(i+1)*line_length+" / "+total_images+"] \n [Total time left : "+Time_express_V2((total_images-(total_images_[u]+(i+1)*line_length))*(t2-t1)/line_length)+"]", t_Open, t_Reg, t_Ren, t_Write);
		}
		// close all
			close("*"); close(Table.title);
			print("   Preparation/Registration time: "+Time_express_V2(t2-t0)); 
	}
setBatchMode("exit and display");
eval("js","IJ.getInstance().setSize(new Dimension(600, 120))");
}



/////////////////////////////////////////////////////////////	/// REG REC RAPID // 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	/// REG REC RAPID // 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	/// REG REC RAPID // 	////////////////////////////////////////////////////////////////////////////////////////////////////

if (Choice_macro == "Reg+Rec_Rapid") { Version = 1.0;
	print(" \n----------------------------------Rapid Registration ----------------------------------------");
	eval("js","IJ.getInstance().setSize(new Dimension(480, 60))");
	setBatchMode("hide"); 
	

	
	//loop for each folder
	for (u = 0; u < umax; u++) {
		print("----   "+File.getName(inputDir[u])+" : ");
		line_length 				= line_length_[u];
		column_length 				= column_length_[u];
		Bool_Binning_at_Opening     = Bool_Binning_at_Opening_[u];
		Bool_Align_line 			= Bool_Align_line_[u];
		divg_max					= divg_max_[u];
		Bool_Mean_scan				= Bool_Mean_scan_[u];
		Bool_Background				= Bool_Background_[u];
		GB_choice					= GB_choice_[u];
		Bool_generate_preparation	= Bool_generate_preparation_[u];
		//Bool_Registration			= Bool_Registration_[u];
		prominence					= prominence_[u];
		Bool_Spot_radius_fixed		= Bool_Spot_radius_fixed_[u];
		Radius_start				= Radius_start_[u];
		Radius_final				= Radius_final_[u];
		nSpots_max					= nSpots_max_[u];
		
		Bool_Rename_image			= Bool_Rename_image_[u];
		image_name					= image_name_[u];
		Bool_Rename_image_auto		= Bool_Rename_image_auto_[u];
	
		extension = ""; extension = extension+"_Dim(0-"+column_length+",0-"+line_length+")";
						if(Bool_Align_line == 1) {extension = extension+"_Al["+remove_comma_in_string_of_number(divg_max)+"]";}
						if(Bool_Mean_scan == 1) {extension = extension+"_Mean["+kernelsize+"]";}
						if(Bool_Background == 1) {extension = extension+"_Bg["+Background_size+"]";}
						if(Bool_Spot_radius_fixed == 1) {extension = extension+"_Rapid";}			
						if(GB_choice != 0) {extension = extension+"_Gb["+GB_choice+"]";}
						if(Bool_Registration == 1) {extension = extension+"_Reg["+prominence+"]"+"["+Radius_start+"]"+"["+nSpots_max+"]";}				
						
		directory = inputDir[u];
		WorkDir= File.getParent(directory);
		namefolder = "randomstring";
		namefolder = File.getName(directory);
		output= File.makeDirectory(WorkDir+"\\"+namefolder+extension);
		output=WorkDir+"\\"+namefolder+extension;
/* !! */	if (Choice_macro=="Registration+Reconstruction") {output_[u]=output;}
			if (Choice_macro=="Reg+Rec_Rapid") {output_[u]=output;}
		
		
		//print("   Start Spots Registration by lines method (Version "+Version+") \n   "+directory+" \n   "+"Options"+extension+" \n   Scan size used : X= "+line_length+", Y= "+column_length+" \n   [dataset "+u+1+"/"+umax+"] Registration...");
		print("   "+directory+" \n   "+"Options"+extension+" \n   Scan size used : X= "+line_length+", Y= "+column_length+" \n   [dataset "+u+1+"/"+umax+"] Registration...");
		t0=getTime(); 
	
		for (i = 0; i < column_length; i++) {
				t1=getTime();
	
			//open useful lines / alignment included
				if(isOpen("line_"+i) != 1) { open_line(i); 
					if(Bool_Binning_at_Opening == 1) {run("Size...", "width=512 height=512 depth="+nSlices+" constrain average interpolation=Bilinear");}
					if(Bool_Align_line == 1) {Align_Stack_XmYm_Adaptative_V2(divg_max);}}
					
				if(isOpen("line_"+(i+1)) != 1 && i != column_length-1) { open_line(i+1); 
					if(Bool_Binning_at_Opening == 1) {run("Size...", "width=512 height=512 depth="+nSlices+" constrain average interpolation=Bilinear");}
					if(Bool_Align_line == 1) {Align_Stack_XmYm_Adaptative_V2(divg_max);}}
				
			//mean of the lines around line i, the function takes the border in account //mean along the line
				if(Bool_Mean_scan == 1) {Mean_line(i); Mean_stack_k3();	}
				
			//Substract Background
				if(Bool_Background == 1) {Background_size = getWidth/10; run("Subtract Background...", "rolling="+Background_size+" sliding stack");}
				
			//Registration here
				if(Bool_Registration == 1 && Bool_Spot_radius_fixed == 0) {title = Spot_registration_stack_V6(prominence, Radius_start, nSpots_max, i, GB_choice);}		
				if(Bool_Registration == 1 && Bool_Spot_radius_fixed == 1) {title = Spot_registration_stack_V6_radius_fixed(prominence, Radius_start, Radius_final, nSpots_max, i, GB_choice);}		
			
			//rename slices
				if(Bool_Rename_image_auto == 1) {image_name = namefolder+extension;}
				if(Bool_Rename_image == 1 || Bool_Rename_image_auto == 1) {for (k = 1; k <= nSlices; k++) {setSlice(k); run("Set Label...", "label="+image_name+"_"+IJ.pad(i, 4)+"-"+IJ.pad(k, 4));}}
				if(Bool_Rename_image == 0 && Bool_Rename_image_auto == 0) {for (k = 1; k <= nSlices; k++) {setSlice(k); run("Set Label...", "label="+IJ.pad(i, 4)+"-"+IJ.pad(k, 4));}}
			
			//save as images
				if(Bool_generate_preparation == 1) {run("Image Sequence... ", "select="+output+" dir="+output+" format=BMP name=name use");}
					
			//close useless line/stacks
				if(isOpen("line_"+(i-1)) == 1) { close("line_"+(i-1)); }
				if(isOpen("Mean_line_"+i) == 1) { close("Mean_line_"+i); }
				if(isOpen("line_"+(i-1)) == 1) { close("Result_line"+i); }
				//close("Mean_line_"+i); close("Result_line"+i);
			
			t2=getTime();
			print("\\Update:   [dataset "+u+1+"/"+umax+"]"+"[line "+i+1+" / "+column_length+"] \n [Time left : "+Time_express_V2((column_length-1-i)*(t2-t1)));
		
		}
		// close all
			close("*"); close(Table.title);
			print("   Preparation/Registration time: "+Time_express_V2(t2-t0)); 
	}
setBatchMode("exit and display");
eval("js","IJ.getInstance().setSize(new Dimension(600, 120))");
}
/////////////////////////////////////////////////////////////	REGISTRATION	+	RECONSTRUCTION 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	REGISTRATION	+	RECONSTRUCTION 	////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	REGISTRATION	+	RECONSTRUCTION 	////////////////////////////////////////////////////////////////////////////////////////////////////

// Mix the Dialogs,
// Affect output form registration as inputDir for reconstruction

if (Choice_macro == "Registration+Reconstruction") {
	//print("\nChanging source directories for reconstruction...");
		for (u = 0; u < umax; u++) {
			inputDir[u]=output_[u]; print(" \t Tables written in : \t"+inputDir[u]);
		}
}

if (Choice_macro == "Reg+Rec_Rapid") {
	//print("\nChanging source directories for reconstruction...");
		for (u = 0; u < umax; u++) {
			inputDir[u]=output_[u]; print(" \t Tables written in : \t"+inputDir[u]);
		}
}


/////////////////////////////////////////////////////////////	RECONSTRUCTION 		////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	RECONSTRUCTION 		////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////	RECONSTRUCTION 		////////////////////////////////////////////////////////////////////////////////////////////////////


if (Choice_macro == "Reconstruction" || Choice_macro == "Registration+Reconstruction" || Choice_macro == "Reg+Rec_Rapid") { Version = 4.0;
//if (Choice_macro == "Reconstruction" || Choice_macro == "Registration+Reconstruction") { Version = 4.0;
	print(" \n--------------------------------------- Reconstruction ---------------------------------------");
	//print("Folder Process- Reconstruction from CSV \t Version "+Version+" \n ");
		
	eval("js","IJ.getInstance().setSize(new Dimension(480, 60))");												//to reduce main menu display (performance ++)
	//eval("js","rm = RoiManager.getInstance2();rm.setVisible(false);");
	setBatchMode("hide"); 
	t1=getTime();
	
	for (u = 0; u < umax; u++) {
		print("----   "+File.getName(inputDir[u])+" : ");
		t0=getTime();
		directory 					= inputDir[u];
		Bool_align_from_CSV 		= Bool_align_from_CSV_[u];
		image_size					= image_size_[u];
		upsize						= upsize_[u];
		R_factor_1					= R_factor_1_[u];
		R_factor_2					= R_factor_2_[u];
		GB							= GB_[u];
		Bool_no_reconstruction			= Bool_no_reconstruction_[u];
		Bool_virtual_brightfield 		= Bool_virtual_brightfield_[u];
		Bool_full_virtual_brightfield 	= Bool_full_virtual_brightfield_[u];
		Bool_spot_count_map 			= Bool_spot_count_map_[u];
		Bool_StdDev_map 				= Bool_StdDev_map_[u];
		Bool_Prominence_min_map 		= Bool_Prominence_min_map_[u];
		Bool_pro_pseudo_map				= Bool_pro_pseudo_map_[u];
		
		
		//print("   Start Spots Reconstruction from CSV (Version "+Version+") \n   "+directory+" \n   "+"Options"+extension+" \n   [dataset "+u+1+"/"+umax+"] Reconstruction...");
		extension ="";
		extension = extension+"_Rc["+upsize*image_size+"_to_"+image_size+"]"+"R["+R_factor_1+"]"+"["+R_factor_2+"]"+"M["+d2s(M_factor_a, 2)+"]"+"Gb["+GB+"]";
		print("   "+directory);
		if(Bool_no_reconstruction != 1){print("   "+"Options"+extension);} else {print("No reconstruction. Only maps will be written.");}

		// Open data
			if (File.exists(directory+"/"+"Results_All.csv") != 1){print("Assembling csv..."); Assemble_csv_files(directory); }						// assemble table as one if not done
			else {print(directory+File.separator+"Results_All.csv"+" exists");open(directory+File.separator+"Results_All.csv");}
			Table.setLocationAndSize(screenWidth, screenHeight, 0, 0);
		
		// Original_Size_of_image
			if (round(Table.get('X_acc', 0)/256) == 1) {image_size_default=512;}
			if (round(Table.get('X_acc', 0)/256) == 2) {image_size_default=1024;}
			if (round(Table.get('X_acc', 0)/256) == 4) {image_size_default=2048;}
			if (round(Table.get('X_acc', 0)/256) == 8) {image_size_default=4096;}
			
		// Collect data in arrays
			Table_size = Table.size;
			Nx = Table.get("X_scan", Table_size-1); Ny = Table.get("Y_scan", Table_size-1);
			N = Nx*Ny;
			Headings = Table.headings; 
			last1 = lastIndexOf(Headings, "StdDev"); STDDEV_exists = false; if(last1 != -1){STDDEV_exists = true;}
			lastpro = lastIndexOf(Headings, "Prominence_pseudo"); PRO_exists = false; if(lastpro != -1){PRO_exists = true;}
			
			X_scan = newArray(Table_size);
			Y_scan = newArray(Table_size);
			X_acc_all = newArray(Table_size);
			Y_acc_all = newArray(Table_size);
			R_all = newArray(Table_size);
			M_all = newArray(Table_size);
			VB=newArray(N);
			VFB=newArray(N);
			VC=newArray(N);
			vb_count = -1; Xvb=0; Yvb=0; // actually the X and Y of scan starts at (1, 1) in the main CSV file.
			fvb_count = -1; Xfvb=0; Yfvb=0;
			vc_count = -1; Xvc=0; Yvc=0;
			//if stdev exists in the table
			if(STDDEV_exists == true){
				STDDEV_all = newArray(Table_size);
				PMIN_all = newArray(Table_size);
				VSTD=newArray(N);
				VPMIN=newArray(N);
				std_count = -1; Xstd=0; Ystd=0;
				pmin_count = -1; Xpmin=0; Ypmin=0;
			}
			if (PRO_exists == true) {
				PRO_all=newArray(Table_size);
				VPRO=newArray(N);
				vpro_count = -1; Xpro=0; Ypro=0;
			}

		
				for (i = 0; i < Table_size; i++) {
					X_scan[i] = Table.get('X_scan', i)*(image_size/image_size_default);
					Y_scan[i] = Table.get('Y_scan', i)*(image_size/image_size_default);		
					X_acc_all[i] = Table.get('X_acc', i)*(image_size/image_size_default);
					Y_acc_all[i] = Table.get('Y_acc', i)*(image_size/image_size_default);
					R_all[i] = Table.get('Radius', i)*(image_size/image_size_default);
					M_all[i] = Table.get('Mean', i);

					if(Bool_virtual_brightfield == 1) { //Full Virtual Brightfield :each pixel is the of some all spots intensities
						if (X_scan[i] != Xvb || Y_scan[i] != Yvb) {vb_count++; VB[vb_count]=M_all[i]; Xvb = X_scan[i];Yvb = Y_scan[i]; }
					}
					if(Bool_full_virtual_brightfield == 1) { //Full Virtual Brightfield :each pixel is the of some all spots intensities
						if (X_scan[i] != Xfvb || Y_scan[i] != Yfvb) {fvb_count++; VFB[fvb_count]=0; Xfvb = X_scan[i];Yfvb = Y_scan[i]; }
						VFB[fvb_count] = VFB[fvb_count]+M_all[i];					
					}
					if(Bool_spot_count_map == 1) { //spot count map :each pixel is the number of spots
						if (X_scan[i] != Xvc || Y_scan[i] != Yvc) {vc_count++; VC[vc_count]=0; Xvc = X_scan[i];Yvc = Y_scan[i]; }
						VC[vc_count] = VC[vc_count]+1;				
					}
					if(STDDEV_exists == true){
						STDDEV_all[i] = Table.get('StdDev', i);
						PMIN_all[i] = Table.get('Prominence_min', i);
						if(Bool_StdDev_map == 1) { //spot count map :each pixel is the number of spots
							if (X_scan[i] != Xstd || Y_scan[i] != Ystd) {std_count++; VSTD[std_count]=STDDEV_all[i]; Xstd = X_scan[i];Ystd = Y_scan[i]; }
						}
						if(Bool_Prominence_min_map == 1) { //spot count map :each pixel is the number of spots
							if (X_scan[i] != Xpmin || Y_scan[i] != Ypmin) {pmin_count++; VPMIN[pmin_count]=PMIN_all[i]; Xpmin = X_scan[i];Ypmin = Y_scan[i]; }		
						}
					}
					if(PRO_exists == true){
						PRO_all[i] = Table.get('Prominence_pseudo', i);
						if(Bool_pro_pseudo_map == 1) { //spot count map :each pixel is the number of spots
							if (X_scan[i] != Xpro || Y_scan[i] != Ypro) {vpro_count++; VPRO[vpro_count]=0; Xpro = X_scan[i];Ypro = Y_scan[i]; }
							VPRO[vpro_count]=VPRO[vpro_count]+PRO_all[i];
						}
					}
				}
		t01 = getTime(); 
		if (Bool_align_from_CSV != 1) {close(Table.title);}
		
		// Set output directory
		extension="";
		parent= File.getParent(directory);
		namefolder = "randomstring";
		namefolder = File.getName(directory); 
		if (lastIndexOf(namefolder, "Dim(") == -1) {extension = extension+"_Dim(0-"+Ny+",0-"+Nx+")";}
		if (Bool_align_from_CSV == 1) {extension = extension+"_Al[]";}
		extension = extension+"_Rc["+upsize*image_size+"_to_"+image_size+"]"+"R["+R_factor_1+"]"+"["+R_factor_2+"]"+"M["+d2s(M_factor_a, 2)+"]"+"Gb["+GB+"]";
		if(Bool_no_reconstruction != 1){
			output= File.makeDirectory(parent + File.separator + namefolder + extension);
			output= parent + File.separator + namefolder + extension;
			print("   Reconstruction Output: "+output+" \n ");} // \\Update:   

		
		// Draw maps
		// genrerate and save FULL virtual brightfield (only reflections)
		if(Bool_virtual_brightfield == 1) { x=0; y=0; newImage("VB", "32-bit black", Nx, Ny, 1);				
			for(p=0; p<VB.length; p++) {if(x>=Nx) {x=0; y++;} setPixel(x, y, VB[p]); x++;		}
			saveAs("Tiff", parent+File.separator+"VB_"+namefolder+extension+".tif");close();
		}	
		// genrerate and save FULL virtual brightfield (only reflections)
		if(Bool_full_virtual_brightfield == 1) {x=0; y=0; newImage("Full_VB", "32-bit black", Nx, Ny, 1);				
			for(p=0; p<VFB.length; p++) {if(x>=Nx) {x=0; y++;} setPixel(x, y, VFB[p]); x++;		}
			saveAs("Tiff", parent+File.separator+"Full_VB_"+namefolder+extension+".tif"); close();
		}	
		// genrerate and save Spot count map
		if(Bool_spot_count_map == 1) {	x=0; y=0; newImage("Spot_Count_map_", "32-bit black", Nx, Ny, 1);	//normalization of intensitycanceled , so 1 level is 1 spot count in 32-bits			
			for(p=0; p<VC.length; p++) {if(x>=Nx) {x=0; y++;} setPixel(x, y, VC[p]); x++;		}
			saveAs("Tiff", parent+File.separator+"Spot_Count_map_"+namefolder+extension+".tif");close();
		}	
		if(STDDEV_exists == true){
			// genrerate and save the Standard deviation map
			if(Bool_StdDev_map == 1) {x=0; y=0; newImage("StdDev_map_", "32-bit black", Nx, Ny, 1);				
				for(p=0; p<VSTD.length; p++) {if(x>=Nx) {x=0; y++;} setPixel(x, y, VSTD[p]); x++;		}
				saveAs("Tiff", parent+File.separator+"StdDev_map_"+namefolder+extension+".tif");close();
			}
			// genrerate and save the map of minimum prominence to register spots in the pattern
			if(Bool_Prominence_min_map == 1) {x=0; y=0; newImage("Prominence_min_map_", "32-bit black", Nx, Ny, 1);				
				for(p=0; p<VPMIN.length; p++) {if(x>=Nx) {x=0; y++;} setPixel(x, y, VPMIN[p]); x++;		}
				saveAs("Tiff", parent+File.separator+"Prominence_min_map_"+namefolder+extension+".tif");close();
			}	
		}
		if(PRO_exists == true){
			// genrerate and save the Standard deviation map
			if(Bool_pro_pseudo_map == 1) {x=0; y=0; newImage("Prominence_pseudo_map_", "32-bit black", Nx, Ny, 1);				
				for(p=0; p<VPRO.length; p++) {if(x>=Nx) {x=0; y++;} setPixel(x, y, VPRO[p]); x++;		}
				saveAs("Tiff", parent+File.separator+"Prominence_pseudo_map_"+namefolder+extension+".tif");close();
			}
		}
	
		t1 = getTime();	
		
		// Draw reflections
		
		if(Bool_no_reconstruction != 1) {		
			step_show = 0; s = 0; X=0; Y=0; ID = -1; stack_name = "Stack_";
			for (i = 0; i < Table_size; i++) {			
				if (Y_scan[i] != Y) {
					if (isOpen(stack_name)==1) {
						if(upsize != 1){run("Size...", "width="+image_size+" height="+image_size+" depth="+Nx+" constrain average interpolation=Bilinear");}
						run("Gaussian Blur...", "sigma="+GB+" stack");
						run("Image Sequence... ", "select="+output+" dir="+output+" format=BMP name=[] use");
						close(stack_name);
					}
					stack_name = "Stack_"+Y_scan[i];
					newImage(stack_name, "8-bit black", upsize*image_size, upsize*image_size, Nx);
					s = 0;
					ID = getImageID(); run("Select None");run("Clear Results");
				}	
				main_spot = false;
				//R = R_all[i];
				if (X_scan[i] != X || Y_scan[i] != Y) {main_spot = true; s++; X = X_scan[i];Y = Y_scan[i];}		
				if(Bool_align_from_CSV == 1){	    
					if(main_spot == true) {Dx = X_acc_all[i]-(image_size_default/2); Dy = Y_acc_all[i]-(image_size_default/2); 		//MEASURE shift and correct
						X_acc_all[i]=X_acc_all[i]-Dx; Y_acc_all[i]=Y_acc_all[i]-Dy;}													//MEASURE shift and correct
					if(main_spot == false) {X_acc_all[i]=X_acc_all[i]-Dx; Y_acc_all[i]=Y_acc_all[i]-Dy;} 							// correct shift
				} 																				
				if(main_spot == true) {setSlice(s); run("Set Label...", "label="+IJ.pad(Y_scan[i], 4)+"-"+IJ.pad(X_scan[i], 4));}	//move to next slice & rename slices 
				if(main_spot == true) {Draw_spot_V2(upsize*X_acc_all[i], upsize*Y_acc_all[i], upsize*R_factor_1*(image_size/image_size_default), M_all[i]);}
				if(main_spot == false) {Draw_spot_V2(upsize*X_acc_all[i], upsize*Y_acc_all[i], upsize*R_factor_2*(image_size/image_size_default), M_all[i]);}
			 	if (i==step_show) {t2 = getTime(); print("\\Update:   [dataset "+u+1+"/"+umax+"][Drawing reflection "+(i)+"/"+Table_size+"] \t "+d2s(100*(i/Table_size), 1)+" % \t To go : "+Time_express_V2((Table_size-i)*(t2-t1)/(i))+" \n Results read in "+Time_express_V2(t01-t0)+" Ellapsed : "+Time_express_V2(t2-t1)+" ");step_show += 1000;}
			}	
				if(upsize != 1){run("Size...", "width="+image_size+" height="+image_size+" depth="+Nx+" constrain average interpolation=Bilinear");}
				//print("\\Update:   [dataset "+u+1+"/"+umax+"][Gaussian Blur...", "sigma="+GB+" stack ("+N+" slices ~ "+d2s(20/10000*N, 0)+" s)]");
				run("Gaussian Blur...", "sigma="+GB+" stack");
				run("Image Sequence... ", "select="+output+" dir="+output+" format=BMP name=[] use");
				close();		
		}
		
		t3 = getTime();
					
		// Save aligned table
			if (Bool_align_from_CSV == 1) {
				Table.setColumn("X_scan", X_scan);
				Table.setColumn("Y_scan", Y_scan);
				// other data depending only on scan position is not useful to rewrite in fact
				Table.setColumn("X_acc", X_acc_all);
				Table.setColumn("Y_acc", Y_acc_all);	
				Table.setColumn("Radius", R_all);
				Table.setColumn("Mean", M_all);
				if(STDDEV_exists == true){
					Table.setColumn("StdDev", STDDEV_all);
					Table.setColumn("Prominence_min", PMIN_all);
				}
				if(PRO_exists == true){
					Table.setColumn("Prominence_pseudo", PRO_all);
				}
				Table.save(directory+"/"+"Results_All_Al[].csv");
				close(Table.title);
			}
			
		// Clean selection / temporary results
			run("Select None");run("Clear Results");

		t4 = getTime();
		print("\\Update:   [dataset "+u+1+"/"+umax+"][Dataset reconstructed : "+Nx+" * "+Ny+" = "+ N +" images] "+" \n Read "+d2s((t01-t0)/1000, 1)+" s, Draw "+d2s((t3-t1)/1000, 1)+" s, Write "+d2s((t4-t3)/1000, 1)+" s, Maps "+d2s((t1-t01)/1000, 1)+" s");
		total_time = (t4-t0); 
		if(total_time <= 60) {print("   Total reconstruction time: "+Time_express_V2(total_time));} 
		else {print("   Total reconstruction time: "+Time_express_V2(total_time));}
	}
	setBatchMode("exit and display");
	eval("js","IJ.getInstance().setSize(new Dimension(600, 120))");
	//eval("js","rm = RoiManager.getInstance2();rm.setVisible(true);");
}

Work_time= getTime()-Work_time; Date_2 = Date_Express(); print("\nAll Processes Finished in "+Time_express_V2(Work_time) +"\nfrom   "+Date_1 +"\nto       "+Date_2);
print("------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
///////////////////////////////////////////////////////////////////////	FUNCTIONS 	////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////	FUNCTIONS 	////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////	FUNCTIONS 	////////////////////////////////////////////////////////////////////////////////////////////////////


//--------------------------------------------------------Opening lines as stacks---------------------------------------------------//


function open_line(i) { 	//open a line i
	run("Image Sequence...", "dir=["+directory+"] start="+i*line_length+1+" count="+line_length+" step="+step+" sort"); rename("line_"+i); 
}

//-----------------------------------------------------------Mean in scan-----------------------------------------------------------//



function Mean_line(i) {	//Mean of line (2 on edge, 3 in bulk)
	if (i==0) {run("Image Expression Parser (Macro)", "expression=(A+B)/2 a=line_"+(i)+" b=line_"+(i+1));}
	if (i>0 && i<column_length-1) {run("Image Expression Parser (Macro)", "expression=(A+B+C)/3 a=line_"+(i-1)+" b=line_"+i+" c=line_"+(i+1));}
	if (i==column_length-1) {run("Image Expression Parser (Macro)", "expression=(A+B)/2 a=line_"+(i-1)+" b=line_"+(i));}
	run("8-bit"); run("Hyperstack to Stack"); rename("Mean_line_"+i);
	if(isOpen("Exception")==1) {close("Exception");}
}


function Mean_stack_k3() { //Mean in a line of Z neighbour images (take border in account)
  k3 = "[0 1 0 0 1 0 0 1 0]";keep = 0;kernel = k3;id1 = getImageID;id01 = getTitle();
  setVoxelSize(1, 1, 1, "pixel");getMinAndMax(min, max);run("Reslice [/]...", "input=1 output=1 start=Top");id2 = getImageID;
  if (!keep) {selectImage(id1); close;}selectImage(id2);run("Convolve...", "text1="+kernel+" normalize stack");run("Reslice [/]...", "input=1 output=1 start=Top");
  setMinAndMax(min, max); selectImage(id2);close;rename(id01);
}



//--------------------------------------------------------Alignement----------------------------------------------------//


function Align_Stack_XmYm_Adaptative_V2(divg_max) {
	divg_max = 0.1;
	divergence=100;
	Xmasse_=newArray(nSlices); Ymasse_=newArray(nSlices);W =getWidth(); R_align=W/4; R_align_min=30*(W/512);
		for (r = 0; r < 10; r++) {
			if(divergence > divg_max && R_align > R_align_min+divg_max) {
			run("Select None");run("Make Circular Selection...", "radius="+R_align);List.clear(); List.setMeasurements;
				for (i = 1; i <= nSlices; i++) {setSlice(i); Xmasse_[i-1]=getValue("XM");Ymasse_[i-1]=getValue("YM");}
				for (i = 1; i <= nSlices; i++) {setSlice(i); run("Select None"); Dx = W/2 - Xmasse_[i-1]; Dy = W/2 - Ymasse_[i-1];run("Select All");run("Translate...", "x="+Dx+" y="+Dy+" interpolation=Bilinear slice");}
			Array.getStatistics(Xmasse_, XM_min, XM_max, XM_mean, XM_stdDev); Array.getStatistics(Ymasse_, YM_min, YM_max, YM_mean, YM_stdDev);divergence = maxOf(abs(XM_max-W/2), abs(YM_max-W/2));
			} R_align=divergence+R_align_min;
		}	
	run("Select None");
return divergence;
}

//--------------------------------------------Mask on Subtracted Background data--------------------------------------//

function Find_spot_Mask_SubBGdata(BG, GB, PR){

	run("Clear Results"); r = 2;
	ID_raw = getImageID();
	setBackgroundColor(0, 0, 0); if(BG != 0){run("Subtract Background...", "rolling="+BG+" sliding stack");} run("Duplicate...", "duplicate");
	ID_filters = getImageID(); run("Gaussian Blur...", "sigma="+GB+" stack");
	N=nSlices;
	for (i = 1; i <= N; i++) {
		//print("\\Update:["+i+"/"+N+"]");
		run("Clear Results");
		selectImage(ID_filters); setSlice(i);
	    run("Find Maxima...", "prominence="+PR+" strict exclude output=List"); Table.setLocationAndSize(screenWidth, screenHeight, 0, 0);
	    X=Table.getColumn("X"); Y=Table.getColumn("Y");
	    selectImage(ID_raw); setSlice(i);
	    for (m = 0; m < nResults(); m++) {
	    	 makeOval(X[m]-r, Y[m]-r, 2*r+1, 2*r+1); roiManager("Add");	 
	    }
	    roiManager("Combine"); run("Make Inverse"); run("Clear", "slice"); roiManager("Delete"); run("Select None");
	}
	selectImage(ID_filters); close();
}

//---------------------------------------------------Registration--------------------------------------------------------//


function Spot_registration_2_stacks_pos_int_V1(prominence, Radius_start, nSpots_max, line, GB_choice) {
// prominence of spots  / Radius max of a spot ! < d( 2 spots ) / #spots max / current line in scan (0<column_length)
	stack_title= getTitle;
	run("Set Measurements...", "area mean standard min centroid center integrated display redirect=None decimal=4");
	
	//DETECT & REFINE POSITIONS on GB2 filtered
	
	run("Duplicate...", "title="+stack_title+"-positions duplicate");
	run("Gaussian Blur...", "sigma="+GB_choice+" stack");
	N = nSlices;
	for (s = 1; s <= N; s++) {
		selectWindow(stack_title+"-positions"); setSlice(s);run("Clear Results");run("Select None");
		run("Find Maxima...", "prominence="+prominence+" strict exclude output=List"); // give position X Y of pixel (max) of each spot
		run("Unsharp Mask...", "radius=10 mask=0.90 slice");
		Table.setLocationAndSize(screenWidth, screenHeight, 0, 0);
		if (nResults > nSpots_max) {nSpots = nSpots_max;} if (nResults <= nSpots_max) {nSpots = nResults;}
		X_list = newArray(nSpots); Y_list = newArray(nSpots); X_acc = newArray(nSpots); Y_acc = newArray(nSpots); 
		Radius_list = newArray(nSpots); Mean_list = newArray(nSpots); s_ = newArray(nSpots);	
		for (i = 0; i < nSpots; i++) {X_list[i] = getResult('X', i);Y_list[i] = getResult('Y', i);
		}
		run("Clear Results");	
		for (i = 0; i < nSpots; i++) {
			//Affinement of spot positions with GB applied
			selectWindow(stack_title+"-positions"); setSlice(s);
			run("Select None"); spot_pos = Find_spot_position(X_list[i], Y_list[i], Radius_start);
			//Affinement of radius and intensity on raw
			selectWindow(stack_title); setSlice(s);
			run("Select None"); spot_int = Find_spot_Intensity_V2(spot_pos[0], spot_pos[1], Radius_start);
			
			X_acc[i] = spot_pos[0]; Y_acc[i] = spot_pos[1]; Radius_list[i] = spot_int[0]; Mean_list[i] = spot_int[1]; s_[i] = s;
		}
		// concatenate
		if(s==1) {	X_list_all = X_list;Y_list_all = Y_list;X_acc_all = X_acc;Y_acc_all = Y_acc;Radius_list_all = Radius_list;Mean_list_all = Mean_list;s_all = s_;}
		if(s!=1) {	X_list_all = Array.concat(X_list_all,X_list);Y_list_all = Array.concat(Y_list_all,Y_list);X_acc_all = Array.concat(X_acc_all,X_acc);Y_acc_all = Array.concat(Y_acc_all,Y_acc);
					Radius_list_all = Array.concat(Radius_list_all,Radius_list); Mean_list_all = Array.concat(Mean_list_all,Mean_list);s_all = Array.concat(s_all,s_);}
	} 
	Table.setColumn("Slice", s_all); Table.setColumn("X", X_list_all); Table.setColumn("Y", Y_list_all);
	Table.setColumn("X_acc", X_acc_all); Table.setColumn("Y_acc", Y_acc_all); Table.setColumn("Radius", Radius_list_all); Table.setColumn("Mean", Mean_list_all);
	run("Select None"); saveAs("Results", ""+output+"/"+"Results_"+IJ.pad(line, 3)+".csv");
	close(stack_title+"-positions");
	selectWindow(stack_title); 
return stack_title;
}

/*function Spot_registration_2_stacks_pos_int_adaptative_prominence_V1(Bool_Background, prominence, Radius_start, nSpots_max, line, GB_choice) {
		// prominence of spots  / Radius max of a spot ! < d( 2 spots ) / #spots max / current line in scan (0<column_length)
		stack_title= getTitle;
		run("Set Measurements...", "area mean standard min centroid center integrated display redirect=None decimal=4");
		
		//GET Standard Deviation FOR ADPTATIVE PROMINENCE
		
		run("Clear Results");
		run("Make Circular Selection...", "radius="+(getWidth/2));
		run("Make Inverse");
		//List_StdDev = List.clear();
		List_StdDev = newArray(nSlices);
		List_StdDev_no_limit = newArray(nSlices);
		for (s = 1; s <= nSlices; s++) {
		 	setSlice(s);
		 	List.setMeasurements;
		    std = List.getValue("StdDev");
		    List_StdDev[s] = prominence;
		    List_StdDev_no_limit[s]=std;
		    if(std > prominence){List_StdDev[s] = std;}
		}
		
		run("Select None");
		
		if(Bool_Background == 1) {Background_size = getWidth/10; run("Subtract Background...", "rolling="+Background_size+" sliding stack");}
		
		//DETECT & REFINE POSITIONS on GB2 filtered
		
		run("Duplicate...", "title="+stack_title+"-positions duplicate");
		run("Gaussian Blur...", "sigma="+GB_choice+" stack");
		
		selectWindow(stack_title+"-positions");
		for (s = 1; s <= nSlices; s++) {
				
			setSlice(s);run("Clear Results");run("Select None");
			run("Find Maxima...", "prominence="+List_StdDev[s]+" strict exclude output=List"); // give position X Y of pixel (max) of each spot
			run("Unsharp Mask...", "radius=10 mask=0.90 slice");
			Table.setLocationAndSize(screenWidth, screenHeight, 0, 0);
			
			if (nResults > nSpots_max) {nSpots = nSpots_max;} 
			if (nResults <= nSpots_max) {nSpots = nResults;}
			X_list = newArray(nSpots); Y_list = newArray(nSpots); X_acc = newArray(nSpots); Y_acc = newArray(nSpots); 
			s_ = newArray(nSpots); polar_r_ = newArray(nSpots);
			for (i = 0; i < nSpots; i++) {
				X_list[i] = getResult('X', i);Y_list[i] = getResult('Y', i);
				polar_r_[i]=sqrt(Math.sqr(X_list[i]-(getWidth/2))+Math.sqr(Y_list[i]-(getWidth/2)));
				}
			Array.sort(polar_r_, X_list, Y_list);
			run("Clear Results");
			for (i = 0; i < nSpots; i++) {
				//Affinement of spot positions with GB applied
				run("Select None"); 
				if (i == 0) {
				spot_pos = Find_spot_position(X_list[i], Y_list[i], Radius_start+10);
				X_acc[i] = spot_pos[0]; Y_acc[i] = spot_pos[1]; 
				} else {
				spot_pos = Find_spot_position(X_list[i], Y_list[i], Radius_start);
				X_acc[i] = spot_pos[0]; Y_acc[i] = spot_pos[1]; 
				}	
				s_[i] = s;
			}
			Prominence_min_ = newArray(nSpots);
			StdDev_ = newArray(nSpots);
			Pmin=List_StdDev[s];
			StdDev_raw=List_StdDev_no_limit[s];
			Array.fill(Prominence_min_, Pmin); 
			Array.fill(StdDev_, StdDev_raw);
			// concatenate
			if(s==1) {	X_list_all = X_list;Y_list_all = Y_list;X_acc_all = X_acc;Y_acc_all = Y_acc;s_all = s_; 
						 Prominence_min_all = Prominence_min_; StdDev_all = StdDev_;}
			if(s!=1) {	X_list_all = Array.concat(X_list_all,X_list);Y_list_all = Array.concat(Y_list_all,Y_list);X_acc_all = Array.concat(X_acc_all,X_acc);Y_acc_all = Array.concat(Y_acc_all,Y_acc);
						s_all = Array.concat(s_all,s_);
						Prominence_min_all = Array.concat(Prominence_min_all,Prominence_min_);
						StdDev_all = Array.concat(StdDev_all,StdDev_);}
		}
		// Get intensity on spot POSITIONS on substracted background
		selectWindow(stack_title);
		Radius_list_all = newArray(lengthOf(s_all)); Mean_list_all = newArray(lengthOf(s_all));
		for (i = 0; i < lengthOf(s_all); i++) {
			setSlice(s_all[i]);
  			//Affinement of radius and intensity on raw
			run("Select None"); spot_int = Find_spot_Intensity_V2(X_acc_all[i], Y_acc_all[i], Radius_start);
			Radius_list_all[i] = spot_int[0]; Mean_list_all[i] = spot_int[1]; 
		}	      
		Table.setColumn("Slice", s_all); Table.setColumn("X", X_list_all); Table.setColumn("Y", Y_list_all);
		Table.setColumn("X_acc", X_acc_all); Table.setColumn("Y_acc", Y_acc_all);
		Table.setColumn("Radius", Radius_list_all); Table.setColumn("Mean", Mean_list_all);
		Table.setColumn("StdDev", StdDev_all);
		Table.setColumn("Prominence_min", Prominence_min_all);
		run("Select None"); saveAs("Results", ""+output+"/"+"Results_"+IJ.pad(line, 3)+".csv");
		close(stack_title+"-positions");
		selectWindow(stack_title); 
return stack_title;
}*/

function Spot_registration_2_stacks_pos_int_adaptative_prominence_V2(Bool_Background, prominence, Radius_start, nSpots_max, line, GB_choice) {
		// prominence of spots  / Radius max of a spot ! < d( 2 spots ) / #spots max / current line in scan (0<column_length)
		stack_title= getTitle;
		run("Set Measurements...", "area mean standard min centroid center integrated display redirect=None decimal=4");
		
		//GET Standard Deviation FOR ADPTATIVE PROMINENCE
		
		run("Clear Results");
		run("Make Circular Selection...", "radius="+(getWidth/2));
		run("Make Inverse");
		//List_StdDev = List.clear();
		List_StdDev = newArray(nSlices);
		List_StdDev_no_limit = newArray(nSlices);
		for (s = 1; s <= nSlices; s++) {
		 	setSlice(s);
		 	List.setMeasurements;
		    std = List.getValue("StdDev");
		    List_StdDev[s] = prominence;
		    List_StdDev_no_limit[s]=std;
		    if(std > prominence){List_StdDev[s] = std;}
		}
		
		run("Select None");
		
		if(Bool_Background == 1) {Background_size = getWidth/10; run("Subtract Background...", "rolling="+Background_size+" sliding stack");}
		
		//DETECT & REFINE POSITIONS on GB2 filtered
		
		run("Duplicate...", "title="+stack_title+"-positions duplicate");
		run("Gaussian Blur...", "sigma="+GB_choice+" stack");
		
		selectWindow(stack_title+"-positions");
		for (s = 1; s <= nSlices; s++) {
				
			setSlice(s);run("Clear Results");run("Select None");
			run("Find Maxima...", "prominence="+List_StdDev[s]+" strict exclude output=[Point Selection]"); // give position X Y of pixel (max) of each spot
			bool_selection = false;
			if(getValue("selection.size")!=0) { bool_selection = true;
				getSelectionCoordinates(X_list, Y_list);
				nSpots_raw = getValue("selection.size");
			
			
				if (nSpots_raw > nSpots_max) {nSpots = nSpots_max;} 
				if (nSpots_raw <= nSpots_max) {nSpots = nSpots_raw;}
				
				X_list = Array.trim(X_list, nSpots);Y_list = Array.trim(Y_list, nSpots);
				X_acc = newArray(nSpots); Y_acc = newArray(nSpots); 
				s_ = newArray(nSpots); polar_r_ = newArray(nSpots);
				Prominence_pseudo_=newArray(nSpots);
				for (i = 0; i < nSpots; i++) {
					polar_r_[i]=sqrt(Math.sqr(X_list[i]-(getWidth/2))+Math.sqr(Y_list[i]-(getWidth/2)));
					}
				Array.sort(polar_r_, X_list, Y_list);
				for (i = 0; i < nSpots; i++) {
					//Affinement of spot positions with GB applied
					run("Select None"); 
					if (i == 0) {
					spot_pos = Find_spot_position(X_list[i], Y_list[i], Radius_start+10);
					X_acc[i] = spot_pos[0]; Y_acc[i] = spot_pos[1]; 
					Prominence_pseudo_[i] = Find_pseudo_Prominence_V4(X_list[i], Y_list[i], Radius_start+30);
					} else {
					spot_pos = Find_spot_position(X_list[i], Y_list[i], Radius_start);
					X_acc[i] = spot_pos[0]; Y_acc[i] = spot_pos[1]; 
					Prominence_pseudo_[i] = Find_pseudo_Prominence_V4(X_list[i], Y_list[i], Radius_start+15);
					}	
					s_[i] = s;
				}
				
				Prominence_min_ = newArray(nSpots);
				StdDev_ = newArray(nSpots);
				Pmin=List_StdDev[s];
				StdDev_raw=List_StdDev_no_limit[s];
				Array.fill(Prominence_min_, Pmin); 
				Array.fill(StdDev_, StdDev_raw);
				// concatenate
				if(s==1) {	X_list_all = X_list;Y_list_all = Y_list;X_acc_all = X_acc;Y_acc_all = Y_acc;s_all = s_; 
							 Prominence_min_all = Prominence_min_; StdDev_all = StdDev_; Prominence_pseudo_all=Prominence_pseudo_;}
				if(s!=1) {	X_list_all = Array.concat(X_list_all,X_list);Y_list_all = Array.concat(Y_list_all,Y_list);X_acc_all = Array.concat(X_acc_all,X_acc);Y_acc_all = Array.concat(Y_acc_all,Y_acc);
							s_all = Array.concat(s_all,s_);
							Prominence_min_all = Array.concat(Prominence_min_all,Prominence_min_);
							StdDev_all = Array.concat(StdDev_all,StdDev_);
							Prominence_pseudo_all = Array.concat(Prominence_pseudo_all, Prominence_pseudo_);}
			}
		}
		if(bool_selection == true){
			
			// Get intensity on spot POSITIONS on substracted background
			selectWindow(stack_title);
			Radius_list_all = newArray(lengthOf(s_all)); Mean_list_all = newArray(lengthOf(s_all));
			for (i = 0; i < lengthOf(s_all); i++) {
				setSlice(s_all[i]);
	  			//Affinement of radius and intensity on raw
				run("Select None"); spot_int = Find_spot_Intensity_V2(X_acc_all[i], Y_acc_all[i], Radius_start);
									Radius_list_all[i] = spot_int[0]; Mean_list_all[i] = spot_int[1]; 
			}
			Table.create("Results"); Table.setLocationAndSize(screenWidth, screenHeight, 0, 0);
			Table.setColumn("Slice", s_all); Table.setColumn("X", X_list_all); Table.setColumn("Y", Y_list_all);
			Table.setColumn("X_acc", X_acc_all); Table.setColumn("Y_acc", Y_acc_all);
			Table.setColumn("Radius", Radius_list_all); Table.setColumn("Mean", Mean_list_all);
			Table.setColumn("Prominence_pseudo", Prominence_pseudo_all);
			Table.setColumn("StdDev", StdDev_all);
			Table.setColumn("Prominence_min", Prominence_min_all);
			run("Select None"); saveAs("Results", ""+output+"/"+"Results_"+IJ.pad(line, 3)+".csv");
		}
		close(stack_title+"-positions");
		selectWindow(stack_title); 
return stack_title;

function Find_spot_position(X_ini, Y_ini, r_ini) {     ///////////////////  EN COURS
	//startin X, Y and r of research of the spot
	X= X_ini; Y = Y_ini; r=r_ini;
	line = 0;
	XM=newArray(0, 0); YM=newArray(0, 0); 
	for (i = 0; i < 5; i++) {
		run("Specify...", "width="+r+" height="+r+" x="+X+" y="+Y+" centered");
		List.setMeasurements; 
			X = List.getValue("XM"); XM[line]=X;
			Y = List.getValue("YM"); YM[line]=Y;
		line++;
	}
	spot = newArray(X, Y);
return spot;
}

function Find_spot_Intensity(X_ini, Y_ini, r_ini) { 
	//startin X, Y and r of research of the spot
	r=r_ini;
	STD = newArray(0, 0); RS=newArray(0, 0); M_=newArray(0, 0);
	line = 0;
	for (i = 2; i < 20; i++) {
		r=i;  
		RS[line]= r;
		run("Specify...", "width="+r+" height="+r+" x="+X_ini+" y="+Y_ini+" oval centered");
		List.setMeasurements; 
			STD[line]= List.getValue("StdDev");
			M_[line] = List.getValue("Mean");
		line++;
	}
	STDmax = Array.findMaxima(STD, 0); r = RS[STDmax[0]]; 
	m = M_[0]; //m = M_[STDmax[0]]; 
	//change M_[index] to corresponding i to get a fixed radius measure (i=0 is r=2px)
	spot = newArray(r, m);		
return spot;
}

function Find_spot_Intensity_V2(X_ini, Y_ini, r_ini) { //r fixed
	//startin X, Y and r of research of the spot   WITH r fixed
	r=3;
		run("Specify...", "width="+r+" height="+r+" x="+X_ini+" y="+Y_ini+" oval centered");
		List.setMeasurements; 
			m = List.getValue("Mean");
	spot = newArray(r, m);		
return spot;
}

function Find_pseudo_Prominence_V4(X, Y, r) { //r fixed
	//startin X, Y and r of research of the spot   WITH r fixed
		run("Specify...", "width="+r+" height="+r+" x="+X+" y="+Y+" oval centered");
		List.setMeasurements; 
			min = List.getValue("Min");
		pro = getPixel(X, Y)-min;
return pro;
}

function Find_spot(X_ini, Y_ini, r_ini) { 
	//startin X, Y and r of research of the spot
	step_r = 0.5;tol=1;step_tol = 0.5;med = 0;score_ = newArray((2*tol/step_tol+1)*(2*tol/step_tol+1));
	XM_ = newArray((2*tol/step_tol+1)*(2*tol/step_tol+1));YM_ = newArray((2*tol/step_tol+1)*(2*tol/step_tol+1));IntDen_ = newArray((2*tol/step_tol+1)*(2*tol/step_tol+1));
	SD_ = newArray(r_ini/step_r);M_ = newArray(r_ini/step_r);r_ = newArray(r_ini/step_r);
	cnt=0; r=r_ini;
	for (X = X_ini-tol; X <= X_ini+tol; X+=step_tol) {
		for (Y = Y_ini-tol; Y <= Y_ini+tol; Y+=step_tol) {
		run("Select None");makeOval(X-r, Y-r, 2*r, 2*r);List.setMeasurements;XM = List.getValue("XM");YM = List.getValue("YM");IntDen = List.getValue("IntDen");
		if(X == X_ini && Y == Y_ini) {med=cnt;} XM_[cnt] = XM; YM_[cnt]=YM; IntDen_[cnt]=IntDen; cnt++;
		}
	}
	IntDen_max = Array.findMaxima(IntDen_, 0); //pos of max in list
	if(lengthOf(IntDen_max) != 0) {X = XM_[IntDen_max[0]];Y = YM_[IntDen_max[0]];}
	if(lengthOf(IntDen_max) == 0) {X = XM_[med];Y = YM_[med];}
	cnt=0;
  	for (r = r_ini; r > 1; r-=step_r) {run("Select None");makeOval(X-r, Y-r, 2*r, 2*r);List.setMeasurements;
		SD = List.getValue("StdDev"); SD_[cnt] = SD; r_[cnt] = r;M = List.getValue("Mean"); M_[cnt] = M;cnt++; //Take into account an intensity maximum nly around Center of Mass of spot ???? Mean is ok Correctif artefacts
	}
 	SD_max = Array.findMaxima(SD_, 0.01); //pos of max in list
	if(lengthOf(SD_max) != 0) {r = r_[SD_max[0]]; M = M_[SD_max[0]];}
	spot = newArray(X, Y, r, M);
return spot;
}

function Spot_registration_stack_V6_radius_fixed(prominence, Radius_start, Radius_final, nSpots_max, line, GB_choice) {
// prominence of spots  / Radius max of a spot ! < d( 2 spots ) / #spots max / current line in scan (0<column_length)

	run("Set Measurements...", "area mean standard min centroid center integrated display redirect=None decimal=3");
	run("Gaussian Blur...", "sigma="+GB_choice+" stack");
	for (s = 1; s <= nSlices; s++) {setSlice(s);run("Clear Results");run("Select None");
		run("Find Maxima...", "prominence="+prominence+" strict exclude output=List"); // give position X Y of pixel (max) of each spot
		Table.setLocationAndSize(screenWidth, screenHeight, 0, 0);
		if (nResults > nSpots_max) {nSpots = nSpots_max;} if (nResults <= nSpots_max) {nSpots = nResults;}
		X_list = newArray(nSpots); Y_list = newArray(nSpots); X_acc = newArray(nSpots); Y_acc = newArray(nSpots); 
		Radius_list = newArray(nSpots); Mean_list = newArray(nSpots); s_ = newArray(nSpots);
		for (i = 0; i < nSpots; i++) {X_list[i] = getResult('X', i);Y_list[i] = getResult('Y', i);}
		run("Clear Results");
		//Affinement of spot positions and radius (take mean also) && Affinement intensities as a function of GB applied
		for (i = 0; i < nSpots; i++) {
			spot = Find_spot_fixed_radius(X_list[i], Y_list[i], Radius_start, Radius_final); // spot = newArray(X, Y, r, M);
			X_acc[i] = spot[0]; Y_acc[i] = spot[1]; Radius_list[i] = spot[2]; 	
							
			if(GB_choice==0){Mean_list[i]=spot[3]/1.00;} // GB 0
			if(GB_choice==1){Mean_list[i]=spot[3]/0.90;} // GB 1
			if(GB_choice==2){Mean_list[i]=spot[3]/0.70;} // GB 2
			if(GB_choice==3){Mean_list[i]=spot[3]/0.52;} // GB 3
			if(GB_choice==4){Mean_list[i]=spot[3]/0.38;} // GB 4
		 s_[i] = s;}
		
		// concatenate
		if(s==1) {	X_list_all = X_list;Y_list_all = Y_list;X_acc_all = X_acc;Y_acc_all = Y_acc;Radius_list_all = Radius_list;Mean_list_all = Mean_list;s_all = s_;}
		if(s!=1) {	X_list_all = Array.concat(X_list_all,X_list);Y_list_all = Array.concat(Y_list_all,Y_list);X_acc_all = Array.concat(X_acc_all,X_acc);Y_acc_all = Array.concat(Y_acc_all,Y_acc);
					Radius_list_all = Array.concat(Radius_list_all,Radius_list); Mean_list_all = Array.concat(Mean_list_all,Mean_list);s_all = Array.concat(s_all,s_);}
	} 
	Table.setColumn("Slice", s_all); Table.setColumn("X", X_list_all); Table.setColumn("Y", Y_list_all);
	Table.setColumn("X_acc", X_acc_all); Table.setColumn("Y_acc", Y_acc_all); Table.setColumn("Radius", Radius_list_all); Table.setColumn("Mean", Mean_list_all);
	run("Select None"); saveAs("Results", ""+output+"/"+"Results_"+IJ.pad(line, 3)+".csv"); title = getTitle();
return title;
}

function Find_spot_fixed_radius(X_ini, Y_ini, r_ini, r_final) { 
X= X_ini; Y = Y_ini;
	r=r_ini;
	for (i = 0; i < 5; i++) {
		run("Select None");makeOval(X-r, Y-r, 2*r, 2*r);
		List.setMeasurements;
		X = List.getValue("XM");Y = List.getValue("YM");				
	}		
	r=r_final;	
		run("Select None");makeOval(X-r, Y-r, 2*r, 2*r);List.setMeasurements;
		M = List.getValue("Mean");
	spot = newArray(X, Y, r, M);
return spot;
}

//---------------------------------------------------Assembling CSV--------------------------------------------------------//

function Assemble_csv_files(directory) { 
	// Concatenate csv files of line registration of 4dstem dataset. Changes the presentation of data with intro of scan coordinates.
	t001=getTime();
	filelist = getFileList(directory);
	csv_list = newArray(2); csv_count = 0;
	for (i = 0; i < lengthOf(filelist); i++) {
	    if (endsWith(filelist[i], ".csv") && filelist[i] != "Results_ALL.csv") { csv_list[csv_count] = filelist[i];csv_count++;} csv_list = Array.trim(csv_list, csv_count);
	}
	for (i = 0; i < csv_count; i++) {Table.open(directory+"/"+"Results_"+IJ.pad(i, 3)+".csv");Table.setLocationAndSize(screenWidth, screenHeight, 0, 0);
				if(i==0){			
					X_scan= Table.getColumn("Slice");Xm_	= Table.getColumn("X_acc");Ym_	= Table.getColumn("Y_acc");
					R_	= Table.getColumn("Radius");M_	= Table.getColumn("Mean");		
					//if table headings contains "StdDev"
					Headings = Table.headings; 
					last1 = lastIndexOf(Headings, "StdDev"); STDDEV_exists=false; if(last1 != -1){STDDEV_exists = true;}
					if(STDDEV_exists == true){StdDev_=Table.getColumn("StdDev");Prominence_min_=Table.getColumn("Prominence_min");}
					lastpro = lastIndexOf(Headings, "StdDev"); PRO_exists=false; if(lastpro != -1){PRO_exists = true;}
					if(PRO_exists == true){PRO_=Table.getColumn("Prominence_pseudo");}
					Y_scan = newArray(Table.size);Array.fill(Y_scan, 1);} 
				else {
					a = Table.getColumn("Slice");d = Table.getColumn("X_acc");e = Table.getColumn("Y_acc");
					f = Table.getColumn("Radius");g = Table.getColumn("Mean");h = newArray(Table.size); Array.fill(h, i+1);
					if(STDDEV_exists == true){k = Table.getColumn("StdDev");l = Table.getColumn("Prominence_min");}
					if(PRO_exists == true){p_=Table.getColumn("Prominence_pseudo");}
					X_scan= Array.concat(X_scan, a);Y_scan = Array.concat(Y_scan, h);Xm_	= Array.concat(Xm_,d);Ym_	= Array.concat(Ym_,e);
					R_	= Array.concat(R_,f);M_	= Array.concat(M_,g);
					if(STDDEV_exists == true){StdDev_	= Array.concat(StdDev_,k);Prominence_min_	= Array.concat(Prominence_min_, l);}
					if(PRO_exists == true){PRO_	= Array.concat(PRO_,p_);}
				}
				close("Results_"+IJ.pad(i, 3)+".csv"); print("\\Update:[dataset "+u+1+"/"+umax+"][Concatenate CSV "+(i+1)+"/"+csv_count+"]");
	}						
	Table.create("Results_ALL");
	Table.setColumn("X_scan", X_scan); Table.setColumn("Y_scan", Y_scan); 
	Table.setColumn("X_acc", Xm_);Table.setColumn("Y_acc", Ym_);
	Table.setColumn("Radius", R_);Table.setColumn("Mean", M_);
	Table.setColumn("StdDev", StdDev_);
	Table.setColumn("Prominence_min", Prominence_min_);
	Table.setColumn("Prominence_pseudo", PRO_);
		//rad_center_ = newArray(lengthOf(Y_scan));
		//for (i = 0; i < lengthOf(Y_scan); i++) {rad_center_[i]=sqrt((Xm_[i]-256)*(Xm_[i]-256)+(Ym_[i]-256)*(Ym_[i]-256));}
		//Table.setColumn("Polar_radius", rad_center_);
	Table.save(directory+"/"+"Results_All.csv");
	t002=getTime();print("\\Update:   [dataset "+u+1+"/"+umax+"]["+csv_count+"/"+csv_count+" CSV assembled in "+(t002-t001)/1000+" s]");
}

//-------------------------------------------------------Drawing spots-----------------------------------------------------//

function Draw_spot_V2(X_acc, Y_acc, R, M) { 
	//Draw a spot in two steps : place on a pixel, translate with interpolation to exact location with sub-px accuracy.
	run("Select None");setForegroundColor(M, M, M);X = round(X_acc); Y = round(Y_acc);fillOval(X-R, Y-R, 2*R, 2*R);
	makeOval(X-R, Y-R, 2*R, 2*R); run("Translate...", "x="+(X_acc-X)+" y="+(Y_acc-Y)+" interpolation=Bilinear"); run("Select None");
}
 
//-------------------------------------------------------Parse Scan Size-----------------------------------------------------//

function Find_X_Y_in_path(path) { // Read scan dimensions in path
	par1 = lastIndexOf(path, "(");par2 = lastIndexOf(path, ")");
	if (par1 != -1 && par2 != -1) {text_par = substring(path, par1+1, par2);vir = lastIndexOf(text_par, ",");tir1 = indexOf(text_par, "-");tir2 = lastIndexOf(text_par, "-");
		block1 = substring(text_par, tir1+1, vir);block2 = substring(text_par, tir2+1, lengthOf(text_par));X = parseInt(block2)+1;Y = parseInt(block1)+1;
		print("Scan size proposed: "+X+", "+Y);SIZE=newArray(X, Y);
	} else {SIZE = newArray(200, 200);}
return SIZE;
}

function Correct_scan_size(X, Y, Size_real, Search_Range) { 
	solution_found = false;
	Size_solution = "";
	ratio = 1; X_sol = X; Y_sol=Y; sol_X=X; sol_Y = Y;
	if(Size[0]*Size[1] != Size_real) {
		print("   Size ("+X+"*"+Y+" = "+X*Y+") not matching with file count ("+Size_real+")");
		for (i = (-1)*Search_Range; i < Search_Range; i++) {
		for (j = (-1)*Search_Range; j < Search_Range; j++) {
				if ((X+i)*(Y+j) == Size_real){ solution_found = true;
					if(abs(1-(X+i)/(Y+j)) < ratio) {ratio = abs(1-(X+i)/(Y+j)); sol_X = abs(X+i); sol_Y=abs(Y+j);}}}}
		if (X > Y) {X_sol = maxOf(sol_X, sol_Y); Y_sol = minOf(sol_X, sol_Y);}
		if (X < Y) {X_sol = minOf(sol_X, sol_Y); Y_sol = maxOf(sol_X, sol_Y);}
		if (X == Y) {X_sol = sol_X; Y_sol = sol_Y;}
		Size_solution=toString(X_sol)+" "+toString(Y_sol);
		if(solution_found == true) {print("   Solution found : ("+Size_solution+")  ! may be inversed");Size_solution = "   Solution found : ("+Size_solution+")  ! may be inversed";} 
		else {print("   Solution not found in range"); Size_solution = "   Solution not found in range";}} 
	 else {print("   Size is correct (may be inversed)"); Size_solution = "   Size is correct (may be inversed)";}
	 output_size_solution = newArray(Size_solution, X_sol, Y_sol);
return output_size_solution;
}

//--------------------------------------------------------Treat strings--------------------------------------------------------//

function remove_comma_in_string_of_number(number) { 
	// works for 1 comma "." in number
	string_without_comma=substring(toString(number), 0, indexOf(toString(number), ".")) + substring(toString(number), indexOf(toString(number), ".")+1);
return toString(string_without_comma);
}

function Directory_name(inputDir) {
 	//get last directory in path
	Simple_directory = inputDir; last1 = lastIndexOf(inputDir, File.separator);
	if(last1 != -1){ sub1=substring(inputDir, 0, last1); last2 = lastIndexOf(sub1, File.separator); if(last2 != -1){ Simple_directory=substring(sub1, last2+1);}} 
return Simple_directory;
}

function Check_path__folder_name_replacer(path) {
// check path validity, if there are spaces in the string of path, propose to replace all spaces in path by underscores "_".
	if(lastIndexOf(path, " ") != -1) {
		print("! WARNING ! Path name will not work: '"+path+ "' \n Please rename path by:  '"+replace(path, " ", "_"));
		
		Dialog.create("Invalid path name");
		Dialog.addMessage("! WARNING ! Path name will not work: '"+path+ "' \n Please rename path by:  '"+replace(path, " ", "_")+" \n AND/OR avoid any special characters. \n Please check that you select a folder and not a file.");
		Dialog.addCheckbox("Replace all spaces by underscores in path and Continue ?", true);
		Dialog.show();
		if (Dialog.getCheckbox()) {
			old_name_folder = File.getName(path);
			new_name_folder = replace(old_name_folder, " ", "_"); 
			index_folder = lastIndexOf(path, old_name_folder);
			path2 = substring(path, 0, index_folder)+new_name_folder+File.separator;
			File.rename(path, path2);
			print(path +" \n has been replaced by '"+path2+"'");
			path=path2;
			print("Macro will work with the folder '"+path2+"'");}
		else { print(path +" is invalid");}
	}
return path;
}
//------------------------------------------------------ Decoration ----------------------------------------------------------------//

function Display_Version(Version) { 
// function description
/*
 * 
print("             ///////////////////////////////////////////////////////////////////////////////////////////////				");
print("            //                                                                                              //				");
print("           //          Registration and/or Reconstruction script V."+Version+"             //				");
print("            //                                                                                              //				");
print("             ///////////////////////////////////////////////////////////////////////////////////////////////				");
*/
/*
print("___________________________________________________________________________________________");
print("|               Registration and/or Reconstruction script V."+Version+"            |");
print("|_________________________________________________________________________________________|");
print("|                      0                      |                                           |");
print("|                     O O                     |                                           |");
print("|            0       O   O       0            |                                           |");
print("|           O O     O     O     O O           |                    0                      |");
print("|          O   O   O       O   O   O          |          0         O          0           |");
print("|     0   O     OOO         OOO     O   0     |          O         O          O           |");
print("|    O OOO                           OOO O    |    0     O         O          O      0    |");
print("| OOO                                     OOO |    O     O         O          O      O    |");
print("|O                                           O|OOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOO|");
print("|     .     .         .          .      .     |    .     .         .          .      .    |");
print("|_____________________________________________|___________________________________________|");*/
print("_____________________________________________________________________");
print("                                 Registration and/or Reconstruction script V."+Version+"                           ");
print("_____________________________________________________________________");
/*
print("|                                  0                                |                                                                    |");
print("|                                 0 0                              |                                                                    |");
print("|                 	    0         0   0        0                   |                                                                    |");
print("|                    0 0      0     0      0 0                 |                                 0                                 |");
print("|                  0    0    0       0    0   0                |                   0            0            0                   |");
print("|         0     0       000         000     0     0        |        0         0            0            0                   |");
print("|       0 000                                    000  0      |        0         0            0            0         0        |");
print("|  000                                                     000 |        0         0            0            0         0        |");
print("|0                                                                0|0000000000000000000000000000000000|");
//print("|         .         .             .              .          .        |         .         .             .              .          .        |");
print("|__________________________________|__________________________________|");
*/
/*print("                     /\                                                                          ");
print("                    /  \                                                                         ");
print("            /\     /    \     /\                                     |                           ");
print("           /  \___/      \___/  \                                    |                           ");
print("     /\___/                      \___/\                     |        |        |                  ");
print("  __/                                  \__           |      |        |        |      |           ");
print(" /                                        \_________/ \____/_\______/ \______/_\____/ \_____     ");
print("     .      .        .        .      .               .      .        .        .      .           ");*/
}
//-------------------------------------------------		Date & Time		------------------------------------------------------------//

function Time_express_V2(milliseconds) { 
	totalSecs = milliseconds/1000;
	hours =  (totalSecs - (totalSecs%3600))/3600 ;
	minutes = Math.floor((totalSecs % 3600) / 60);
	seconds = totalSecs % 60;
	if(toString(seconds, 0) == "60") {minutes++; seconds = 0;}
	if(toString(minutes, 0) == "60") {hours++; minutes = 0;}
		if (hours == 0) {
			if (minutes == 0) {timeString = toString(seconds, 0) + " s ";}
			else {timeString = toString(minutes, 0) + " min " + toString(seconds, 0) + " s ";}
		} else { timeString = toString(hours, 0) +" h "+ toString(minutes, 0) + " min " + toString(seconds, 0) + " s ";}
return timeString; 
}

function Date_Express() {
	Formatted_Date = "";
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	Formatted_Date = ""+dayOfMonth+"/"+ month+"/"+ year+" "+ IJ.pad(hour, 2)+":"+ IJ.pad(minute, 2)+":"+ IJ.pad(second, 2);
	return Formatted_Date;
}

//--------------------------------------------------	Help file	------------------------------------------------------------------//

function return_html_help() {
	html = "<html>"
     +"<h2><font color=red><font size=+2>Help - Extend this window for better reading.</font></font></h2>"
     +"<font size=+1>
     +"<br><b>Scan title</b> 
     +"<br> &emsp The title is automatically taken as the name of the image folder."
     +"<br> &emsp   It will be used to name the new folders for registration and reconstruction."
     
     +"<br><br><b>Scan size</b>"
     +"<br> &emsp <font color=blue>X</font> goes left column to right column."
     +"<br> &emsp <font color=blue>Y</font> goes top to bottom rows."
     +"<br> &emsp This script reads the name of the folder and parse <font color=blue>X</font> and <font color=blue>Y</font>."  
     +"<br> &emsp The size of the list of images helps then to find a matching couple (<font color=blue>X</font>,<font color=blue>Y</font>)."
     +"<br> &emsp The given solution respects the initial <font color=blue>X</font> less/more than <font color=blue>Y</font> relation."
     +"<br> &emsp Note: <font color=blue>Y</font> = 3 at least when using  mean scan function. "
     +"<br> &emsp Note: If treating none 4D data (for ex. tomogramm is 1 row of images), "
     +"<br> &emsp &emsp please use <font color=blue>Y</font>=1 without Mean filter for better performance."
     
     +"<br><br><b>Data preparation</b>"
     +"<br> &emsp - <font color=blue>Binning images to 512 px</font> reduces the time of processing."
     +"<br> &emsp - <font color=blue>Alignment</font> is performed by tracking the center of mass of the central spot."
     +"<br> &emsp - <font color=blue>Mean filter</font> is a mean function over 9 images in a kernel 3x3."
     +"<br> &emsp - <font color=blue>Substract background</font> is a function substracting a mean over 50 px."
     +"<br> &emsp - Option to write or not the filteblue images: "
     +"<br> &emsp &emsp If checked, it will write the images with YYYY-XXXX.bmp suffix."
     +"<br> &emsp &emsp A custom prefix can be used. "
     +"<br> &emsp &emsp An automatic renamer takes scan title as a prefix."
     
	 +"<br><br><b>Registration</b>"	
	 +"<br> &emsp The data preparation is strongly recommended."
	 +"<br> &emsp New folder created according to registration parameters. "
	 +"<br> &emsp Data registered written in 1 .csv file per scan line (<font color=blue>Y</font>)."
	 +"<br> &emsp - How does it work: "
	 +"<br> &emsp &emsp 1. Localisation with a 1px accuracy with a prominence parameter."
	 +"<br> &emsp &emsp 2. Position and radius affinement using repectively the center of mass and the integrated density of spots."
	 +"<br> &emsp &emsp 3. The intenisty of the spot is taken as the mean within its radius."
	 +"<br> &emsp - <font color=blue>Prominence</font> should be between 3 and 10."
	 +"<br> &emsp &emsp Increasing the prominence provides safety from registering artefacts  or noise, "
	 +"<br> &emsp &emsp but decreases the chance to register the weakest spots."
     +"<br> &emsp - The <font color=blue>radius start</font>t should be the bigger spot radius possible."
     +"<br> &emsp &emsp It helps to get the final radius value for each spot. "
     +"<br> &emsp &emsp In the case where there is very close spots in image, "
     +"<br> &emsp &emsp the radius start should stay inferior to the interspot distance."
     +"<br> &emsp - <font color=blue>nSpots max</font> is a maximum limit of number of spots to be registered per image."
     +"<br> &emsp &emsp Note : The spots are sorted by prominence, so the weakest reflections are cut "
     +"<br> &emsp &emsp if the image contains more spots than this limit."
     
     +"<br><br><b>Reconstruction</b>"	
	 +"<br> &emsp If the registration is done apart, select the folders containing the csv files."
	 +"<br> &emsp - <font color=blue>Refine alignment</font>: "
	 +"<br> &emsp &emsp Shifts all spots positions so the central spot is exactly in the middle of the image."
	 +"<br> &emsp &emsp It doesn't affect the performance." 
	 +"<br> &emsp - <font color=blue>Spot radius</font> for central and other spots:"
	 +"<br> &emsp &emsp To replace the radius of spots to draw by one value, in case of radius registration accuracy is not satisfying."
     +"<br> &emsp - The <font color=blue>Gaussian blur</font> enhance the spot profile"
     +"<br> &emsp &emsp It helps to get the final shape and mean value for each spot. "
     +"<br> &emsp &emsp The mean is corrected according to the size of the Gaussian blur."
     +"<br> &emsp &emsp The <font color=blue>Virtual Darkfield</font> may be generated as a .bmp image."
     +"<br> &emsp &emsp It provides the sum of intensity mean of spots for each image. "
     +"<br> &emsp &emsp This operation take the only diffraction signal into account."
     
     +"</font>";
return html;
}
