/* 
 * Macro template to process multiple folders of type HourXX/MinuteXX/SecondXX/FrameXX.dm4
 * Converted (bmp 8-bits) files are written in a automatically created folder in Main Output Folder.
 * An option "Console clear" is used to empty the console log of Fiji that gives a lot of error messages 
 * due to the Bio-formats plugin usage. Set the delay depending on computer performance from 50 ms to few seconds, 
 * increase it especially for big image sizes (4K, 2K ...). For typical 512*512 32 bits dm4, 
 * set to a 500ms to avoid lags.
 */

// Set max number  of folders to include
	Dialog.create("Maximum Number of Folders");
	Dialog.addNumber("MaxNumber of Folders", 1);
	Dialog.addNumber("Console is cleared if t(iteration) >", 500, 0, 4, "ms");
	Dialog.show();
	umax=Dialog.getNumber()+1;
	t3=Dialog.getNumber();

//choose input data folder(s)
inputDir = newArray(umax);
for (u = 1; u < umax; u++) {
	inputDir[u]= getDirectory("Choose input directory "+u);
}

//choose where ALL results directories will be written
WorkDir = getDirectory("Choose MAIN OUTPUT directory "); //testing

//Console placement message for automatic clearing (performance increased, not touch mouse while processing
waitForUser("Place your Console Window in Top Left Corner of screen to avoid slowing down (> 80% !!) process");


//loop for each folder
for (u = 1; u < umax; u++) {

// #@ File (label = "Input directory", style = "directory") input ;
suffix=".dm4";

input=inputDir[u];

//WorkDir= File.getParent(input);

name = "randomstring";
name = File.getName(input);
output= File.makeDirectory(WorkDir+"\\"+name+"_8b_bmp");
output=WorkDir+"\\"+name+"_8b_bmp";


print(output);


// See also Process_Folder.py for a version of this code
// in the Python scripting language.

setBatchMode("hide");

// scan folders/subfolders/files to estimate number of files with correct suffix
number_images_total=0;
	hours=0;
	minutes=0;
	seconds=0;
	frames=0;
	list_hours = getFileList(input);
	hours = list_hours.length;
	//print(hours);
	list_minutes = getFileList(input + File.separator + list_hours[0]);
	minutes = list_minutes.length;
	//print(minutes);
	list_seconds = getFileList(input + File.separator + list_hours[0] + File.separator + list_minutes[0]);
	seconds = list_seconds.length;
	//print(seconds);
	list_frames = getFileList(input + File.separator + list_hours[0] + File.separator + list_minutes[0] + File.separator + list_seconds[0]);
	frames = list_frames.length; //  /2 if bmp and dm4 coexist
	//print(frames);

	number_images_total=hours*minutes*seconds*frames;
	print("\\Update[2]:[counting finished \t Estimated number of images : "+number_images_total+" ("+hours+"*"+minutes+"*"+seconds+"*"+frames+")]");



processFolder(input);

/////// F	U	N	C	T	I	O	N	S	////////////////////

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i], t3);
	}
}

function processFile(input, output, file, t3) {
	
	t1=getTime();
	//	Counnt active frame/total
	Name=list[i];
	current_hour = (IJ.pad(parseInt(substring(Name, lastIndexOf(Name, "Hour")+5, lastIndexOf(Name, "Hour")+7)), 2));
	current_minute = (IJ.pad(parseInt(substring(Name, lastIndexOf(Name, "Minute")+7, lastIndexOf(Name, "Minute")+9)), 2));
	current_second =(IJ.pad(parseInt(substring(Name, lastIndexOf(Name, "Second")+7, lastIndexOf(Name, "Second")+9)), 2));
	current_frame =(IJ.pad(parseInt(substring(Name, lastIndexOf(Name, "Frame")+6, lastIndexOf(Name, "Frame")+10)), 4));
	
	progress_hour = current_hour/hours;
	progress_minute =current_minute/minutes;
	progress_second = current_second/seconds;
	progress_frame = current_frame/frames;
	
	//print(minutes*seconds*frames*current_hour+seconds*frames*current_minute+frames*current_second+current_frame+" / "+number_images_total);
	
	//open(input + File.separator + file);
	
		IJ.redirectErrorMessages();
	run("Bio-Formats Windowless Importer", "open="+input + File.separator + file);	//open dm4 with bioformat without dialogue


	//format

	factor_target=0.9990;
	res_bin=100;

	count_total=getWidth()*getHeight();
	getMinAndMax(min, max);
	nBins = Math.floor(max-min)/res_bin;

	stop=0;
	start=0;
	
	//to crop the end of histogramm
	row = 0;
	count_sum=0;
	nBins = Math.floor(max-min)/res_bin;
	getHistogram(values, counts, nBins);
	
	for (i=0; i<nBins; i++) { 
		
		if(count_sum<(factor_target)*count_total) {	      
		      count_sum=count_sum+counts[i];
		      stop=values[i];
		}
	}


	//to crop the start of histogramm (lower res_bin)
	
	res_bin=10000;
	row = 0;
	count_sum=0;
	nBins = Math.floor(max-min)/res_bin;
	getHistogram(values, counts, nBins, min, 0);
	for (i=0; i<nBins; i++) { 
		
		if(count_sum<((1-factor_target))*count_total) {	      
		      count_sum=count_sum+counts[i];
		      if (lengthOf(values) != 0) { //because errors with values[i] empty
		      start=values[i]; 
		      }
		      
		}
	}
	
	
	changeValues(stop,max,stop); //all values more that stop is set to stop
	//changeValues(min,start,0); //all values then than start are step to 0
	run("Enhance Contrast", "saturated=0.15");
	run("8-bit");



	//save
	saveAs("bmp", output + File.separator + file);
	close();

	//LOG
	prog=(minutes*seconds*frames*current_hour+seconds*frames*current_minute+frames*current_second+current_frame)/number_images_total;
	t2=getTime();
	//t3 = 200;
	print("\\Clear");
	print("\\Update[2]:["+output+"]");
	print("\\Update[3]:["+minutes*seconds*frames*current_hour+seconds*frames*current_minute+frames*current_second+current_frame+" / "+number_images_total+"]");
	print("\\Update[4]:[start / stop at gray level "+start+" / "+stop+"]");
	print("\\Update[5]:[(Estimated) "+(prog*100)+"% \t"+getBar(minutes*seconds*frames*current_hour+seconds*frames*current_minute+frames*current_second+current_frame, number_images_total)+"]");
	IJ.log("\\Update[6]:[(Estimated) Time Left : "+Time_express((1-prog)*number_images_total*(t2-t1))+"]");
	IJ.log("\\Update[7]:[(limit to clear : "+t3+" ms) iteration time "+(t2-t1)+" ms]");
	// clear console with robot !!!!! DONT touch the mouse while operating (2 ms operation) == place well the consol in top left corner of screen
	if (t2-t1 > t3) {
	run("Console");
	run("IJ Robot", "order=Left_Click x_point=20 y_point=40 delay=1 keypress=[]");
	run("IJ Robot", "order=Left_Click x_point=20 y_point=60 delay=1 keypress=[]");
	}
}

function Time_express(time) { 
		Hour=Math.floor(time/1000/60/60);
		Minute=Math.floor(time/1000/60)-Hour*60;
		Second=Math.floor(time/1000)-Minute*60;
		Result= toString(Hour) + " h " + toString(Minute) + " min "+toString(Second) + " s ";
		return Result;

}

function getBar(p1, p2) {
        n = 100;
        bar1 = "----------------------------------------------------------------------------------------------------";
        bar2 = "****************************************************************************************************";
        index = round(n*(p1/p2));
        if (index<1) index = 1;
        if (index>n-1) index = n-1;
        return substring(bar2, 0, index) + substring(bar1, index+1, n);
}

setBatchMode("exit and display");

}