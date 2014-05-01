
Sibernetic is a fluid mechanics simulator developed for simulations of C. elegans in the [OpenWorm project](http://www.openworm.org) developed for the [OpenWorm](http://openworm.org) project by Andrey Palyanov, Sergey Khayrulin and Mike Vella as part of the [OpenWorm team](http://www.openworm.org/people.html). Sibernetic provides an implementation of the PCISPH contractile matter algorithm for simulating muscle tissue and is applies to C. elegans locomotion.

When driven by [Hodgkin Huxley dynamics](https://en.wikipedia.org/wiki/Hodgkin%E2%80%93Huxley_model) contractile matter is called Electrofluid.

Sibernetic is primarily written in  C++ and OpenCL, it also provides a Python API.


Compiling / running 
--------------------

**Linux**

Install OpenCL on Ubuntu. We suggest you initially go with [AMD OpenCL drivers](http://developer.amd.com/tools-and-sdks/heterogeneous-computing/amd-accelerated-parallel-processing-app-sdk/downloads/) as we have found these to be the most stable and complete. 

You'll also need a variety of libraries. In ubuntu, install the dependencies with:

```
sudo apt-get install g++ python-dev freeglut3-dev nvidia-opencl-dev libglu1-mesa-dev libglew-dev python-numpy
```

Next, navigate to the `build` folder and run:

```
make clean
make all
```


You should see an output which looks something like this:

```
Building file: ../src/PyramidalSimulation.cpp
Invoking: GCC C++ Compiler
```

Then navigate to the top-level folder in the hierarchy (e.g `Smoothed-Particle-Hydrodynamics`) and set your `PYTHONPATH`:

```
export PYTHONPATH=$PYTHONPATH:'./src'
```

Finally, to run, run the command:

```
./release/sph
```

