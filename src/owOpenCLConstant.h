#ifndef OW_OPENCL_CONSTANT_H
#define OW_OPENCL_CONSTANT_H

const int MAX_NEIGHBOR_COUNT = 32;

const int MAX_MEMBRANES_INCLUDING_SAME_PARTICLE = 7;

const unsigned int LIQUID_PARTICLE = 1;
const unsigned int ELASTIC_PARTICLE = 2;
const unsigned int BOUNDARY_PARTICLE = 3;

const int NO_PARTICLE_ID = -1;
const int NO_CELL_ID = -1;
const float NO_DISTANCE = -1.0f;
const bool QUEUE_EACH_KERNEL = true;


#endif // #ifndef OW_OPENCL_CONSTANT_H
