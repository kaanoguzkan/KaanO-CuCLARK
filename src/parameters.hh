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

////
// Variant-specific defines (selected at compile time)
//
// HTSIZE formula — pick the largest prime that fits your RAM:
//   HTSIZE = largest_prime_below( (RAM_GB - 4) * 1e9 / 24 )
//
//   RAM (GB) | HTSIZE (prime)  | Hash table alloc | Max k (32-bit key)
//   ---------|-----------------|------------------|-------------------
//     8      |   104,395,303   |   ~2.5 GB        | k ≤ 29
//    16      |   268,435,399   |   ~6.4 GB        | k ≤ 30
//    32      |   666,666,671   |  ~16.0 GB        | k ≤ 31
//    48      |   999,999,937   |  ~24.0 GB        | k ≤ 31
//    64      | 1,249,999,993   |  ~30.0 GB        | k ≤ 31
//   128      | 1,610,612,741   |  ~38.6 GB        | k ≤ 31
//
// Override at compile time: cmake -DCUCLARK_HTSIZE=666666671
//
// Max supported k-mer length = floor(log4(HTSIZE)) + 16
// HTSIZE must be prime for good hash distribution.
//
// DBPARTSPERDEVICE: how many DB chunks per GPU (more = less VRAM per chunk)
//   Rule of thumb: ceil(HTSIZE * 24 / (VRAM_bytes - RESERVED))
//
#ifdef CUCLARK_LIGHT
  #ifndef HTSIZE
    #define HTSIZE          57777779
  #endif
  #define MAXHITS         23      // max targets per object (light)
  #define RESERVED        300000000 // reserved GPU memory per batch (light)
  #ifndef DBPARTSPERDEVICE
    #define DBPARTSPERDEVICE 1
  #endif
#elif defined(CUCLARK_MEDIUM)
  #ifndef HTSIZE
    #define HTSIZE          104395303   // ~2.5 GB, fits 8 GB+ RAM
  #endif
  #define MAXHITS         15      // max targets per object
  #define RESERVED        300000000 // reserved GPU memory per batch
  #ifndef DBPARTSPERDEVICE
    #define DBPARTSPERDEVICE 1
  #endif
#else
  #ifndef HTSIZE
    #define HTSIZE          1610612741  // ~38.6 GB, needs 48 GB+ RAM
  #endif
  #define MAXHITS         15      // max targets per object (full)
  #define RESERVED        400000000 // reserved GPU memory per batch (full)
  #ifndef DBPARTSPERDEVICE
    #define DBPARTSPERDEVICE 3
  #endif
#endif
////

#define OBJECTNAMEMAX	40		// maximum length for object names

typedef uint64_t      T64;
typedef uint32_t      T32;
typedef uint16_t      T16;

#endif
