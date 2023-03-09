# ePattern
Image-J macros to register, manage, and reconstruct diffraction data from electron diffraction images.

This folder contains ImageJ macros developped to prepare 4D-STEM data for registration and reconstruction of diffraction signal.

## Purpose
The initial purpose is to use ImageJ tools to optimize the cross-correlation reliability using the ASTAR software suite from Nanomegas.

## Registration
The diffraction signal has to be isolated from background and noise of each pattern (image) of the scan (hyperimage).
The images in input are registered according to the prominence of peaks in the image after removing the background with a rolling ball process.
The information is registered in a table and contains :  
- **Xscan / Yscan**       - the position of a pattern in the scan
- **X_acc Y_acc**         - the position of a reflection in a pattern
- **Mean**                - the intensity of the reflection
- **Radius**              - the size of the reflection
- **StdDev**              - the noise level in the pattern at high angle
- **Prominence_min**      - the minimum prominence applied to detct peaks in the pattern (prominence > StdDev)
- **Prominence_pseudo**   - the diffrence max-min of pixels 'around' the spot (around is defined by user as the minimal distance between two reflections)

## Maps
Several type of maps can be generated to help analsys : 
- **Virtual Brighfield (VB)**            - Draw the central spot intensity over scan (a spot is a reflection)
- **Full Virtual Brighfield (FVB)**       - Draw the sum of all spots intensities for each pattern over scan
- **Virtul Dark Field (VDF)**             - Draww all selected spots intensities for each pattern over scan (user's selections integrated)
- **StdDev map**                    - Draw the value of StdDev over scan
- **Prominence_min map**            - Draw the minimum prominence valuer used to register for each pattern over scan (higher when StdDev is higher)
- **Spot count map**                - Draw the number of (registered) spots in each pattern over scan
                                                                                                
## Reconstruction
Image sequence is needed to compute the cross-correlation (template matching between calculated and experimental patterns) in the ASTAR software suite (Nanomegas).
Thus, a reconstruction of patterns as images is performed from registered data.
The challenge is to draw the spots with a subbpixel accuracy at exact position in a (small) image, with the right intensity.

## Tips and useful hints
- Path in ImageJ doesn't like the spaces, replace them by "_"
- Files format .bmp for images and .csv for tables, also .tif (32-bits) is used for maps accuracy
- Some of the scripts parse the scan dimensions in the folder's name as "(000y-000x)" 
- In scan and images : x is wideness from left, y is height from top (ImageJ)
- Code works only for scans with 2<X<9999 and 1<Y<9999
