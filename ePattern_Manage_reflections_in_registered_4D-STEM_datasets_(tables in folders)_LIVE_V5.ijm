/* Draw a projection of all reflections in table
 *  Allow treshold by Mean or Prominence
 *  Allow a selection of spots to delete
 *  
 *  TO DO:
 *  	-Tiff 32 bits, All packed in one new folder
 *  	- option treshold by nspots in pattern
 */



// to select reflections to delete
#@ File[] inputDir (label="Select folders", style="both")
#@ int Mean_treshold
#@ int Prominence_treshold
umax=lengthOf(inputDir);

for (u = 0; u < umax; u++) {
			directory = inputDir[u];
			print((u+1)+"  "+inputDir[u]);
			print("Waiting for interaction with projection...");

				
			//directory=getDir("");
		filelist = getFileList(directory);	    
			if(File.exists(directory+"/"+"Results_All_Al[].csv")==1){
				Table.open(directory+"/"+"Results_All_Al[].csv");
	
	X_scan_	=Table.getColumn("X_scan"); 
	Y_scan_	=Table.getColumn("Y_scan"); 
	X_acc_	=Table.getColumn("X_acc"); 
	Y_acc_	=Table.getColumn("Y_acc");
	R_		=Table.getColumn("Radius");
	M_		=Table.getColumn("Mean");
	P_		=Table.getColumn("Prominence_pseudo");
	
	X_scan_denoised_ 	=newArray(X_acc_.length);
	Y_scan_denoised_ 	=newArray(X_acc_.length);
	X_acc_denoised_ 	=newArray(X_acc_.length);
	Y_acc_denoised_		=newArray(X_acc_.length);
	R_denoised_ 		=newArray(X_acc_.length);
	M_denoised_ 		=newArray(X_acc_.length);
	P_denoised_ 		=newArray(X_acc_.length);
	
	Table_size=Table.size;
	close("Results_All_Al[].csv");
	
	Amorphous_=newArray(X_acc_.length);
	newImage("Projection", "8-bit black", 512, 512, 1);
	Nspots=0;
	for (i = 0; i < Table_size; i++) {
		if (M_[i]>=Mean_treshold && P_[i]>=Prominence_treshold) {
			setPixel(X_acc_[i], Y_acc_[i], getPixel(X_acc_[i], Y_acc_[i])+1);
			Nspots++;}
	}
	setMinAndMax(0, 0);
	//run("Enhance Contrast", "saturated=0.35");
	setTool("brush");
	
//start live things
	  shift=1;
      ctrl=2; 
      rightButton=4;
      alt=8;
      leftButton=16;
      insideROI = 32; // requires 1.42i or later
		x_map =-1; y_map = -1; value_map = 0;
      x2=-1; y2=-1; z2=-1; flags2=-1;
      s = Prominence_treshold;  //prominence
      m = Mean_treshold;
      histo =0;
      s2 = 10;
		GB = 2;
      logOpened = false;
      if (getVersion>="1.37r"){
          setOption("DisablePopupMenu", true);
		selectWindow("Projection");
	  while (isOpen("Projection")) {
      	//selectWindow("Projection");
      	getCursorLoc(x, y, z, flags);   
          if (flags!=flags2) { 
          				Prominence_treshold=s;
          				Mean_treshold=m;
          				selectWindow("Projection");run("Select All"); run("Clear");
          				run("Select None");
						setFont("SansSerif", 15);
              			makeText("Prominence: "+s+"*", 0, 0);
              			run("Add Selection...", "stroke=grey fill=none new");
              			setFont("SansSerif", 15);
              			makeText("Mean: "+m+"*", 210, 0);
              			run("Add Selection...", "stroke=grey fill=none");
              			setFont("SansSerif", 15);
              			makeText("Histogram: "+histo+"*", 0, 30);
              			run("Add Selection...", "stroke=grey fill=none");
              			setFont("SansSerif", 15);
              			makeText("Spots: "+Nspots+"/"+Table_size+"*", 210, 30);
              			run("Add Selection...", "stroke=grey fill=none");
              			setFont("SansSerif", 15);
              			makeText("Drawing projection...", 0, 60);
              			run("Add Selection...", "stroke=red fill=none");
              			setFont("SansSerif", 10);
              			makeText("LB/RB Prominence UP/DOWN\nShift+RB/RB: Mean UP/DOWN\nCtrl+RB/RB: Histogram UP/DOWN\nAlt+LB CLOSE", getWidth-150, 0);Overlay.addSelection;
						run("Select None");
						Nspots=0;
				for (i = 0; i < Table_size; i++) {
					if (M_[i]>=Mean_treshold && P_[i]>=Prominence_treshold) {
						setPixel(X_acc_[i], Y_acc_[i], getPixel(X_acc_[i], Y_acc_[i])+1);
						Nspots++;}
				} setMinAndMax(0, histo);
						setFont("SansSerif", 15);
						makeText("Prominence: "+s, 0, 0);
              			run("Add Selection...", "stroke=yellow fill=none new");
              			setFont("SansSerif", 15);
              			makeText("Mean: "+m, 210, 0);
              			run("Add Selection...", "stroke=yellow fill=none");
              			setFont("SansSerif", 15);
              			makeText("Histogram: "+histo, 0, 30);
              			run("Add Selection...", "stroke=#0096ff fill=none");
              			setFont("SansSerif", 15);
              			makeText("Spots: "+Nspots+"/"+Table_size, 210, 30);
              			run("Add Selection...", "stroke=#0096ff fill=none");
              			setFont("SansSerif", 10);
              			makeText("LB/RB Prominence UP/DOWN\nShift+RB/RB: Mean UP/DOWN\nCtrl+RB/RB: Histogram UP/DOWN\nAlt+LB CLOSE", getWidth-150, 0);Overlay.addSelection;
						run("Select None");
				
	          if ((flags&ctrl==0 && flags&shift==0) && flags&leftButton!=0) {s++;print("\\Update:[Mean : "+m+"][Prominence: "+s+"][Spots: "+Nspots+"/"+Table_size+"]");
              				if (s>=255){s=255;} 
              				run("Select None");
              	}
              if ((flags&ctrl==0 && flags&shift==0) && flags&rightButton!=0) {s--; print("\\Update:[Mean : "+m+"][Prominence: "+s+"][Spots: "+Nspots+"/"+Table_size+"]");
    						if (s<=1){s=1;}
							run("Select None");
              	}
			if (flags&shift!=0 && flags&leftButton!=0) {m++;print("\\Update:[Mean : "+m+"][Prominence: "+s+"][Spots: "+Nspots+"/"+Table_size+"]");
              				if (m>=255){m=255;} 
              				run("Select None");
              	}
              if (flags&shift!=0 && flags&rightButton!=0) {m--; print("\\Update:[Mean : "+m+"][Prominence: "+s+"][Spots: "+Nspots+"/"+Table_size+"]");
    						if (m<=1){m=1;}
							run("Select None");
				}
			if (flags&ctrl!=0 && flags&leftButton!=0) {histo++;print("\\Update:[Mean : "+m+"][Prominence: "+s+"][Spots: "+Nspots+"/"+Table_size+"]");
              				if (histo>=254){histo=254;} 
              				run("Select None");
              	}
              if (flags&ctrl!=0 && flags&rightButton!=0) {histo--; print("\\Update:[Mean : "+m+"][Prominence: "+s+"][Spots: "+Nspots+"/"+Table_size+"]");
    						if (histo<1){histo=0;}
							run("Select None");
				}
			if (flags&alt!=0 && flags&leftButton!=0) {print("\\Update:[Mean : "+m+"][Prominence: "+s+"][Spots: "+Nspots+"/"+Table_size+"]");  
							close("Projection");
							Prominence_treshold=s;
          					Mean_treshold=m;
				}
              startTime = getTime();
          }
          x2=x; y2=y; z2=z; flags2=flags;
          wait(25);
          //if(isOpen("Original")==false){close("Preview");}
          //if(isOpen("Preview")==false){close("Original");}
      }
	
//end live things

//start manual affinement (select last points to delete)
	newImage("Projection", "32-bit black", 512, 512, 1);
		Nspots=0;
		for (i = 0; i < Table_size; i++) {
			if (M_[i]>=Mean_treshold && P_[i]>=Prominence_treshold) {
				setPixel(X_acc_[i], Y_acc_[i], getPixel(X_acc_[i], Y_acc_[i])+1);
				Nspots++;}
		}
				setMinAndMax(0, histo);
              	run("Select None");
	waitForUser("Select points to delete (new VDF, new Table) \n Tool brush enabled (other tools are selectable) \n *Left click from selected: Draw ROI \n *(hold)Shift+click: Add a separated area to ROI \n *Left Click from out of selected: Remove from ROI \n *Shift+A: Clear ROI");
// create VDF and, Table with removed spots, Projection
	setBatchMode("hide");
	//getSelectionCoordinates(xpoints, ypoints); 
	roiManager("add");
	newImage("Map", "32-bit black", X_scan_[Table_size-1], Y_scan_[Table_size-1], 1);
	c=0;
	for (i = 0; i < Table_size; i++) {
		if (M_[i]>=Mean_treshold && P_[i]>=Prominence_treshold) {
			x=X_acc_[i]; y=Y_acc_[i];
			selectWindow("Projection"); 
			if(Roi.contains(x, y)!=1) { //exclusion of selected reflections to draw VDF
				selectWindow("Map"); 
				setPixel(X_scan_[i]-1, Y_scan_[i]-1, getPixel(X_scan_[i]-1, Y_scan_[i]-1)+1); //-1 because image starts at 0,0
				
				X_scan_denoised_[c]	=X_scan_[i];
				Y_scan_denoised_[c]	=Y_scan_[i];
				X_acc_denoised_[c]	=X_acc_[i];
				Y_acc_denoised_[c]	=Y_acc_[i];
				R_denoised_[c]		=R_[i];
				M_denoised_[c]		=M_[i];
				P_denoised_[c]		=P_[i];
				c++;
				
				//Table.deleteRows(i, i);  //Too long
			}
		}
		showProgress(i, Table_size);
	}
	selectWindow("Map");
	//run("Enhance Contrast", "saturated=0.35");
				
				
	//Check if all positions in scan are represented) == reconstruction take the real size of the scan: X_scan_[Table_size-1], Y_scan_[Table_size-1]
	//last line of table gives the scan size
		X_scan_denoised_ 	= Array.trim(X_scan_denoised_, c);
		Y_scan_denoised_ 	= Array.trim(Y_scan_denoised_, c);
		X_acc_denoised_	 	= Array.trim(X_acc_denoised_, c);
		Y_acc_denoised_ 	= Array.trim(Y_acc_denoised_, c);
		R_denoised_ 		= Array.trim(R_denoised_, c);
		M_denoised_ 		= Array.trim(M_denoised_, c);
		P_denoised_ 		= Array.trim(P_denoised_, c);
		
		X_scan_denoised_[c] 	= X_scan_[Table_size-1];
		Y_scan_denoised_[c] 	= Y_scan_[Table_size-1];
		X_acc_denoised_[c]	= X_acc_[Table_size-1];
		Y_acc_denoised_[c] 	= Y_acc_[Table_size-1];
		R_denoised_[c] 		= 1;
		M_denoised_[c] 		= 1;
		P_denoised_[c] 		= 1;


		
		
		
		
		
	Table.create("Results_All_denoised");
		Table.setColumn("X_scan", X_scan_denoised_);
		Table.setColumn("Y_scan", Y_scan_denoised_);
		Table.setColumn("X_acc", X_acc_denoised_);
		Table.setColumn("Y_acc", Y_acc_denoised_);
		Table.setColumn("Radius", R_denoised_);
		Table.setColumn("Mean", M_denoised_);
		Table.setColumn("Prominence_pseudo", P_denoised_);
	
	setBatchMode("exit and display"); 
	
		//create output directory
		prefix="D_";
			directory = inputDir[u];
			WorkDir= File.getParent(directory);
			namefolder = "randomstring";
			namefolder = File.getName(directory);
			output= File.makeDirectory(WorkDir+"\\"+prefix+namefolder);
			output=WorkDir+"\\"+prefix+namefolder;
		
		Table.save(output+File.separator+"Results_All_denoised["+Prominence_treshold+"]_"+File.getNameWithoutExtension(directory)+".csv");
		Table.save(output+File.separator+"Results_All"+".csv");	
			close("Results_All_denoised");
		selectWindow("Map"); 
			saveAs("Tiff", output+File.separator+"VDF_denoised_"+File.getNameWithoutExtension(directory)+".tif");
			close();
		selectWindow("Projection");
			saveAs("Tiff", output+File.separator+"All_"+File.getNameWithoutExtension(directory)+".tif");
			close();
			close("*");
	}
}
}
print("end");