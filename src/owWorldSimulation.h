#ifndef OW_WORLD_SIMULATION_H
#define OW_WORLD_SIMULATION_H
#include <string.h>
#include <GL/freeglut.h>

#include "owPhysicsFluidSimulator.h"
#include "VectorMath.h"

const unsigned int TIMER_INTERVAL = 30;  //this is the interval between calls to timer func (in milliseconds)
const unsigned int ROTATION_STEP_ANGLE = 1;      //this is the step angle that the mesh will rotate every SOME_INTERVAL milliseconds
void run(int argc, char** argv, const bool with_graphics = true, const bool load_to = false);
#endif //OW_WORLD_SIMULATION_H
