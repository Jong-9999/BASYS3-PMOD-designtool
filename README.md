<img width="255" height="211" alt="image" src="https://github.com/user-attachments/assets/37fe7057-0f1e-4673-87fb-b0c02ea61930" />



xc7a35tcpg236-1


make the Basys 3 pmod (96*64) screen easy to use!


https://digilent.com/shop/pmod-oledrgb-96-x-64-rgb-oled-display-with-16-bit-color-resolution/



just follow the below steps:



1. plug in screen (while powered off) to JB as seen in picture.
2. In vivado, open a new project and add all the design source files as design sources.
3. In vivado, add the constraints .xdc file into constraint file.
4. download the .html and open it. Draw your desired design and copy the entire top module.
5. paste topmodule into Vivado under design sources and set it as top module.
6. generate bitstream


great successs!


**DO NOT REDRAW TRIANGLES IT WILL TAKE UP MANY LOGIC GATES**



Credits:

font design by https://github.com/petabyt


oled driver code by Joel Holdsworth <joel@airwebreathe.org.uk>
