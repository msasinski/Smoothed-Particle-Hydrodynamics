#ifndef OW_PHYSICS_CONSTANT_H
#define OW_PHYSICS_CONSTANT_H

#include "owOpenCLConstant.h"
#include <math.h>

#ifndef M_PI
#define M_PI 3.1415927f
#endif


const float rho0 = 1000.0f;
const float mass = 3.25e-14f;// kg // we need 3.25e-14 kg
//const float mass = 3.25e-08f;
const float timeStep = 5.0e-06f;// s // ATTENTION! too large values can lead to 'explosion' of elastic matter objects
//const float timeStep = 0.2e-04f;
//const float timeStep = 1.0e-02f;

const float simulationScale = 0.004f*pow(mass,1.f/3.f)/pow(0.00025f,1.f/3.f);

const float h = 3.34f;//pow((( 3 * mass * (float)MAX_NEIGHBOR_COUNT )/( 4 * M_PI * rho0 )), 1.f/3.f ) / simulationScale; //3.34f;
const float hashGridCellSize = 2.0f * h;
const float hashGridCellSizeInv = 1.0f / hashGridCellSize;
const float simulationScaleInv = 1.0f / simulationScale;
const float interParticleDistance = 0.5f*h*simulationScale;// should be 1 mm / 311 = 0.0032 mm = 3.2e-6 m
const float preliminaryWormLength = 311 * interParticleDistance;//should be 1 mm = 1e-3 m
const float r0 = 0.5f * h; // distance between two boundary particle == equilibrium distance between 2 particles // Ihmsen et. al., 2010, page 4, line 3
// M. Ihmsen, N. Akinci, M. Gissler, M. Teschner, Boundary Handling and Adaptive Time-stepping for PCISPH Proc. VRIPHYS, Copenhagen, Denmark, pp. 79-88, Nov 11-12, 2010.

//Sizes of the box containing simulated 'world'
//Sizes choice is realized this way because it should be proportional to smoothing radius h
#define XMIN 0
#define XMAX 30.0*h // horizontal 1
#define YMIN 0
#define YMAX 20.0*h // vertical
#define ZMIN 0
#define ZMAX 250.0*h // horizontal 2 //142

//const float h_fall = simulationScale*(YMAX-YMIN)*0.454f;

// Some facts about C. elegans:
// Adult worm mass = 3.25e-06 grams = 3.25e-09 kg
// worm density is around 1000 kg/m3
// Adult worm length =  1 mm =   1000 um =    1e-03 m
// Adult worm broad diameter = 60..80 um = 6..8e-05 m // we'll consider it to be equal 80 um (radius = 40 um)
// Adult worm volume = 0.0033 mm3
//
// 1000*40*40*Cw = 0.0033
// then Cw = 2.0625
//
// so, if we need a worm body model composed of, for example, 1e+05 particles
// each particle's mass should be 3.25e-09 / 1e+05 = 3.25e-14 kg
// and length of the worm will be (caculation follows):
// n - number of particles per 1 um
// (1000*n)*(40*n)*(40*n)*Cw = 1e+5 particles
// then n^3 = 0.303, n = 0.311
// then worm length = (1000*n) = 311 particles, radius = (40*n) = 12 particles
//
// So, in this case (1e+5 particles) we need r0 = 3.2 um = 3.2e-6 m
// and particle mass = 3.25e-14 kg

const float stiffness = 0.75f;	//need description of this parameter
const float viscosity = 0.00005f;//0.00015f;	// liquid viscosity  //why this value? Dynamic viscosity of water at 25 C = 0.89e-3 Pa*s
const float damping = 0.75f;	//need description of this parameter

const float CFLLimit = 100.0f;

const double beta = timeStep*timeStep*mass*mass*2/(rho0*rho0);// B. Solenthaler's dissertation, formula 3.6 (end of page 30)
const double Wpoly6Coefficient = 315.0 / ( 64.0 * M_PI * pow( (double)(h*simulationScale), 9.0 ) );
const float surfTensCoeff = -1.5e-09f * 0.3f* (float)(Wpoly6Coefficient * pow(h*simulationScale*h*simulationScale/2.0,3.0)) * simulationScale;
const double gradWspikyCoefficient= -45.0 / ( M_PI * pow( (double)(h*simulationScale), 6.0 ) );
const double del2WviscosityCoefficient = - gradWspikyCoefficient;
const float gravity_x = 0.0f;
const float gravity_y = -9.8f;
const float gravity_z = 0.0f;
extern const float delta;
const int maxIteration = 3;

#endif // #ifndef OW_PHYSICS_CONSTANT_H