#@ String (choices={"Registration", "Reconstruction", "Registration+Reconstruction"}, style="radioButtonHorizontal") Choice_macro
#@ File[] inputDir (label="select files or folders", style="both")


line_length = 10; column_length = 10; // X, Y // To determine automatically

      
newImage("4D-STEM_MAP", "8-bit black", line_length, column_length, 1); run("Maximize");
	for (xx = 0; xx < getWidth; xx++) {
		for (yy = 0; yy < getHeight; yy++) {
			if ((xx % 2 == 0 && yy % 2 == 0) || (xx % 2 != 0 && yy % 2 != 0)) {setPixel(xx, yy, 50);}
		}
	}run("Maximize"); run("Tile");
filelist = getFileList(inputDir[0]);
name_opened = "";
      shift=1;
      ctrl=2; 
      rightButton=4;
      alt=8;
      leftButton=16;
      insideROI = 32; // requires 1.42i or later
		x_map =-1; y_map = -1; value_map = 0;
      x2=-1; y2=-1; z2=-1; flags2=-1;
      s = 5;  //prominence
      s2 = 10;
		GB = 2;
      logOpened = false;
      if (getVersion>="1.37r")
          setOption("DisablePopupMenu", true);

while (isOpen("4D-STEM_MAP")) {
          getCursorLoc(x, y, z, flags); s = s2;
          if (x!=x2 || y!=y2 || z!=z2 || flags!=flags2) {
              //s = " ";
              if (flags&leftButton!=0){ s = s + "<left>";
              //print(x+" "+y+" "+z+" "+flags + "" + s);
            	print("\\Clear");
               print("\\Update:[opening image : "+x+" "+y+"]");
               adress=y*x+x;
               if(isOpen(name_opened)){close(name_opened);}
               if(x_map != -1 && y_map != -1){ setPixel(x_map,y_map,value_map);}
	               x_map =x; y_map = y; value_map = getPixel(x, y); setPixel(x,y,255);
               open(inputDir[0]+"/"+filelist[adress]); name_opened = getTitle();
               //run("Tile");
    
    //prev = 1;
	
	run("Point Tool...", "type=Dot color=Cyan size=Tiny label counter=0");
	rename("Original");
		run("8-bit");
		run("Select None");
		setFont("SansSerif", 25);
        makeText("Original (X: "+IJ.pad(x, 3)+" Y: "+IJ.pad(y, 3)+")", 0, 0);Overlay.addSelection;
        //run("Add Selection...", "stroke=Cyan fill=#1a1d21 new");
        run("Add Selection...", "stroke=Cyan fill=none new");
        run("Select None");
        
		run("Duplicate...", "title=Preview");
		run("Subtract Background...", "rolling=50 sliding disable");
		run("Gaussian Blur...", "sigma=1");
		run("Enhance Contrast", "saturated=0.35");
		run("Apply LUT");
		run("Tile");
		print("\\Update:[Image : "+x_map+" "+y_map+"][Prominence: "+s2+"]");
						selectWindow("Preview");
						s = s2;
		          		run("Select None");
						setFont("SansSerif", 25);
              			makeText("Prominence: "+s, 0, 0);Overlay.addSelection;
              			run("Add Selection...", "stroke=yellow fill=#660000ff new");
              			setFont("SansSerif", 10);
              			makeText("Shift+LB UP\nCtrl+LB DOWN\nAlt+LB CLOSE", getWidth-70, 0);Overlay.addSelection;
						run("Select None");
						run("Find Maxima...", "prominence="+s+" strict exclude output=[Point Selection]");
						run("Point Tool...", "type=Cross color=Cyan size=Small show counter=0");
						Overlay.addSelection; run("Select None");
			
      while (isOpen("Preview")) {
      	selectWindow("Preview");
      	getCursorLoc(x, y, z, flags);   
          if (flags!=flags2) { 
          				run("Select None");
						setFont("SansSerif", 25);
              			makeText("Prominence: "+s, 0, 0);Overlay.addSelection;
              			run("Add Selection...", "stroke=yellow fill=#660000ff new");
              			setFont("SansSerif", 10);
              			makeText("Shift+LB UP\nCtrl+LB DOWN\nAlt+LB CLOSE", getWidth-70, 0);Overlay.addSelection;
						run("Select None");
						run("Find Maxima...", "prominence="+s+" strict exclude output=[Point Selection]");
						run("Point Tool...", "type=Cross color=Cyan size=Small show counter=0");
						Overlay.addSelection; run("Select None");
              if (flags&shift!=0 && flags&leftButton!=0) {s++;print("\\Update:[Image : "+x_map+" "+y_map+"][Prominence: "+s+"]");
              				run("Select None");
              	}
              if (flags&ctrl!=0 && flags&leftButton!=0) {s--; print("\\Update:[Image : "+x_map+" "+y_map+"][Prominence: "+s+"]");
    						if (s<=1){s=1;}
							run("Select None");
				}
			if (flags&alt!=0 && flags&leftButton!=0) {print("\\Update:[Image : "+x_map+" "+y_map+"][Prominence: "+s+"]");  close("Preview"); close("Original");}
              startTime = getTime();
          }
          x2=x; y2=y; z2=z; flags2=flags;
          //wait(10);
          if(isOpen("Original")==false){close("Preview");}
          if(isOpen("Preview")==false){close("Original");}
      }
          
              startTime = getTime();}
      }
          x2=x; y2=y; z2=z; flags2=flags; s2 =s;
          wait(10);
} close("*");