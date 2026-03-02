/*
   CuCLARK, CLARK for CUDA-enabled GPUs.
   Copyright 2016-2017, Robin Kobus <rkobus@students.uni-mainz.de>
   
   based on CLARK version 1.1.3, CLAssifier based on Reduced K-mers.
   Copyright 2013-2016, Rachid Ounit <rouni001@cs.ucr.edu>


   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * @author: Robin Kobus, masters student at Institute of Computer Science, JGU Mainz
 * @project: CuCLARK, Metagenomic Classification with CUDA-enabled GPUs
 * 
 * Changes:
 * Added additional defines.
 */


#ifndef PARAMETERS_HH
#define PARAMETERS_HH

#define VERSION "1.1"

#define SB              4
#define NBN		1
#define SFACTORMAX 	30

//// variant-specific defines (selected at compile time via -DCUCLARK_LIGHT)
#ifdef CUCLARK_LIGHT
  #define HTSIZE          57777779
  #define MAXHITS         23      // max targets per object (light)
  #define RESERVED        300000000 // reserved GPU memory per batch (light)
  #define DBPARTSPERDEVICE 1
#else
  #define HTSIZE          1610612741
  #define MAXHITS         15      // max targets per object (full)
  #define RESERVED        400000000 // reserved GPU memory per batch (full)
  #define DBPARTSPERDEVICE 3
#endif
////

#define OBJECTNAMEMAX	40		// maximum length for object names

typedef uint64_t      T64;
typedef uint32_t      T32;
typedef uint16_t      T16;

#endif
