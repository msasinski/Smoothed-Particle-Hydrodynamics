// Equations referenced here are from:
// "Particle-based fluid simulation for interactive applications", Muller, Charypar & Gross,
// Eurographics/SIGGRAPH Symposium on Computer Animation (2003).


#ifndef OW_OPENCL_CONSTANT_H
#define OW_OPENCL_CONSTANT_H

#define MAX_NEIGHBOR_COUNT 32

#define MAX_MEMBRANES_INCLUDING_SAME_PARTICLE 7

#define LIQUID_PARTICLE   1
#define ELASTIC_PARTICLE  2
#define BOUNDARY_PARTICLE 3

#define NO_PARTICLE_ID -1
#define NO_CELL_ID -1
#define NO_DISTANCE -1.0f

#define QUEUE_EACH_KERNEL 1

#define INTEL_OPENCL_DEBUG 0

#endif // #ifndef OW_OPENCL_CONSTANT_H

#define POSITION_CELL_ID( i ) i.w

#define PI_CELL_ID( name ) name.x
#define PI_SERIAL_ID( name ) name.y

#define NEIGHBOR_MAP_ID( nm ) nm.x
#define NEIGHBOR_MAP_DISTANCE( nm ) nm.y

#define RHO( i ) i.x
#define RHO_INV( i ) i.y
//#define P( i ) i.z

#define DIVIDE( a, b ) native_divide( a, b )
#define SQRT( x ) native_sqrt( x )
#define DOT( a, b ) dot( a, b )


#if 1
#define SELECT( A, B, C ) select( A, B, (C) * 0xffffffff )
#else
#define SELECT( A, B, C ) C ? B : A
#endif

#pragma OPENCL EXTENSION cl_amd_printf : enable

#ifdef cl_khr_fp64
#pragma OPENCL EXTENSION cl_khr_fp64 : enable
#elif defined(cl_amd_fp64)
#pragma OPENCL EXTENSION cl_amd_fp64 : enable
#else
#error "Double precision floating point not supported by OpenCL implementation."
#endif


// FUNCTION DEPRECATED
// neighborMap should have all values or defauls assigned in findNeighbors kernel
__kernel void clearBuffers(
    __global float2 * neighborMap,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT )return;
    __global float4 * nm = (__global float4 *)neighborMap;
    int outIdx = ( id * MAX_NEIGHBOR_COUNT ) >> 1;//int4 versus int2 addressing
    float4 fdata = (float4)( -1, -1, -1, -1 );
    int i,j,k,mnl;//mnl = membrane number in the list. 0..MAX_MEMBRANES_INCLUDING_SAME_PARTICLE-1

    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
    nm[ outIdx++ ] = fdata;
}

int searchCell(
    int cellId,
    int deltaX,
    int deltaY,
    int deltaZ,
    int gridCellsX,
    int gridCellsY,
    int gridCellsZ,
    int gridCellCount
)
{
    int dx = deltaX;
    int dy = deltaY * gridCellsX;
    int dz = deltaZ * gridCellsX * gridCellsY;
    int newCellId = cellId + dx + dy + dz;
    newCellId = newCellId < 0 ? newCellId + gridCellCount : newCellId;
    newCellId = newCellId >= gridCellCount ? newCellId - gridCellCount : newCellId;
    return newCellId;
}

#define FOUND_NO_NEIGHBOR 0
#define FOUND_ONE_NEIGHBOR 1
#define radius_segments 30

int getMaxIndex(
    float *d_array
)
{
    int result;
    float max_d = -1.f;
    for(int i=0; i<MAX_NEIGHBOR_COUNT; i++)
    {
        if (d_array[i] > max_d)
        {
            max_d = d_array[i];
            result = i;
        }
    }
    return result;
}


int searchForNeighbors_b(
    int searchCell_,
    __global uint * gridCellIndex,
    float4 position_,
    int myParticleId,
    __global float4 * sortedPosition,
    __global float2 * neighborMap,
    int * closest_indexes,
    float * closest_distances,
    int last_farthest,
    int *found_count
)
{
    int baseParticleId = gridCellIndex[ searchCell_ ];
    int nextParticleId = gridCellIndex[ searchCell_ + 1 ];
    int particleCountThisCell = nextParticleId - baseParticleId;
    int i = 0;
    float _distanceSquared;
    int neighborParticleId;

    int farthest_neighbor = last_farthest;

    while( i < particleCountThisCell )
    {

        neighborParticleId = baseParticleId + i;

        if(myParticleId != neighborParticleId)
        {
            float4 d = position_ - sortedPosition[ neighborParticleId ];
            _distanceSquared = d.x*d.x + d.y*d.y + d.z*d.z; // inlined openCL dot(d,d)
            if( _distanceSquared <= closest_distances[farthest_neighbor])
            {
                closest_distances[farthest_neighbor] = _distanceSquared;
                closest_indexes[farthest_neighbor] = neighborParticleId;
                if(*found_count < MAX_NEIGHBOR_COUNT-1)
                {
                    (*found_count)++;
                    farthest_neighbor = *found_count;
                }
                else
                {
                    farthest_neighbor = getMaxIndex(closest_distances);
                }
            }


        }

        i++;

    }//while

    return farthest_neighbor;
}


int4 cellFactors(
    float4 position,
    float xmin,
    float ymin,
    float zmin,
    float hashGridCellSizeInv
)
{
    //xmin, ymin, zmin
    int4 result;
    result.x = (int)( position.x *  hashGridCellSizeInv );
    result.y = (int)( position.y *  hashGridCellSizeInv );
    result.z = (int)( position.z *  hashGridCellSizeInv );
    return result;
}


__kernel void findNeighbors(
    __global uint * gridCellIndexFixedUp,
    __global float4 * sortedPosition,
    int gridCellCount,
    int gridCellsX,
    int gridCellsY,
    int gridCellsZ,
    float h,
    float hashGridCellSize,
    float hashGridCellSizeInv,
    float simulationScale,
    float xmin,
    float ymin,
    float zmin,
    __global float2 * neighborMap,
    int	  PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;
    __global uint * gridCellIndex = gridCellIndexFixedUp;
    float4 position_ = sortedPosition[ id ];
    int myCellId = (int)POSITION_CELL_ID( position_ ) & 0xffff;// truncate to low 16 bits
    int searchCells[8];
    float r_thr2 = h * h;
    float closest_distances[MAX_NEIGHBOR_COUNT];
    int closest_indexes[MAX_NEIGHBOR_COUNT];
    int found_count = 0;

    for(int k=0; k<MAX_NEIGHBOR_COUNT; k++)
    {
        closest_distances[k] = r_thr2;
        closest_indexes[k] = -1;
    }

    searchCells[0] = myCellId;

    // p is the current particle position within the bounds of the hash grid
    float4 p;
    float4 p0 = (float4)( xmin, ymin, zmin, 0.0f );
    p = position_ - p0;

    // cf is the min,min,min corner of the current cell
    int4 cellFactors_ = cellFactors( position_, xmin, ymin, zmin, hashGridCellSizeInv );
    float4 cf;
    cf.x = cellFactors_.x * hashGridCellSize;
    cf.y = cellFactors_.y * hashGridCellSize;
    cf.z = cellFactors_.z * hashGridCellSize;

    // lo.A is true if the current position is in the low half of the cell for dimension A
    int4 lo;
    lo = (( p - cf ) < h );

    int4 delta;
    int4 one = (int4)( 1, 1, 1, 1 );
    delta = one + 2 * lo;

    searchCells[1] = searchCell( myCellId, delta.x, 0, 0, gridCellsX, gridCellsY, gridCellsZ, gridCellCount );
    searchCells[2] = searchCell( myCellId, 0, delta.y, 0, gridCellsX, gridCellsY, gridCellsZ, gridCellCount );
    searchCells[3] = searchCell( myCellId, 0, 0, delta.z, gridCellsX, gridCellsY, gridCellsZ, gridCellCount );
    searchCells[4] = searchCell( myCellId, delta.x, delta.y, 0, gridCellsX, gridCellsY, gridCellsZ, gridCellCount );
    searchCells[5] = searchCell( myCellId, delta.x, 0, delta.z, gridCellsX, gridCellsY, gridCellsZ, gridCellCount );
    searchCells[6] = searchCell( myCellId, 0, delta.y, delta.z, gridCellsX, gridCellsY, gridCellsZ, gridCellCount );
    searchCells[7] = searchCell( myCellId, delta.x, delta.y, delta.z, gridCellsX, gridCellsY, gridCellsZ, gridCellCount );

    // search surrounding cells 1..8
    int last_farthest = 0;

    last_farthest = searchForNeighbors_b( searchCells[0], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count );

    last_farthest = searchForNeighbors_b( searchCells[1], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count  );

    last_farthest = searchForNeighbors_b( searchCells[2], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count  );

    last_farthest = searchForNeighbors_b( searchCells[3], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count  );

    last_farthest = searchForNeighbors_b( searchCells[4], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count  );

    last_farthest = searchForNeighbors_b( searchCells[5], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count  );

    last_farthest = searchForNeighbors_b( searchCells[6], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count  );

    last_farthest = searchForNeighbors_b( searchCells[7], gridCellIndex, position_,
                                          id, sortedPosition, neighborMap,
                                          closest_indexes, closest_distances, last_farthest, &found_count );

    for(int j=0; j<MAX_NEIGHBOR_COUNT; j++)
    {
        float2 neighbor_data;
        neighbor_data.x = closest_indexes[j];
        if(closest_indexes[j] >= 0)
        {
            neighbor_data.y = SQRT( closest_distances[j] ) * simulationScale; // scaled, OK
        }
        else
        {
            neighbor_data.y = -1.f;
        }
        neighborMap[ id*MAX_NEIGHBOR_COUNT + j ] = neighbor_data;
    }


}


int cellId(
    int4 cellFactors_,
    int gridCellsX,
    int gridCellsY,
    int gridCellsZ//don't use
)
{
    int cellId_ = cellFactors_.x + cellFactors_.y * gridCellsX
                  + cellFactors_.z * gridCellsX * gridCellsY;
    return cellId_;
}



__kernel void hashParticles(
    __global float4 * position,
    int gridCellsX,
    int gridCellsY,
    int gridCellsZ,
    float hashGridCellSizeInv,
    float xmin,
    float ymin,
    float zmin,
    __global uint2 * particleIndex,
    int   PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;

    float4 _position = position[ id ];
    int4 cellFactors_ = cellFactors( _position, xmin, ymin, zmin, hashGridCellSizeInv );
    int cellId_ = cellId( cellFactors_, gridCellsX, gridCellsY, gridCellsZ ) & 0xffff; // truncate to low 16 bits
    uint2 result;
    PI_CELL_ID( result ) = cellId_;
    PI_SERIAL_ID( result ) = id;
    particleIndex[ id ] = result;

}

__kernel void indexx(
    __global uint2 * particleIndex,
    int gridCellCount,
    __global uint * gridCellIndex,
    int PARTICLE_COUNT
)
{
    //fill up gridCellIndex
    int id = get_global_id( 0 );
    if( id > gridCellCount  )
    {
        return;
    }

    if( id == gridCellCount )
    {
        // add the nth+1 index value
        gridCellIndex[ id ] = PARTICLE_COUNT;
        return;
    }
    if( id == 0 )
    {
        gridCellIndex[ id ] = 0;
        return;
    }

    // binary search for the starting position in sortedParticleIndex
    int low = 0;
    int high = PARTICLE_COUNT - 1;
    bool converged = false;

    int cellIndex = NO_PARTICLE_ID;
    while( !converged )
    {
        if( low > high )
        {
            converged = true;
            cellIndex = NO_PARTICLE_ID;
            continue;
        }

        int idx = (( high - low )>>1) + low;
        uint2 sampleMinus1 = particleIndex[ idx - 1 ];
        uint2 sample = particleIndex[ idx ];
        int sampleCellId = PI_CELL_ID( sample );
        bool isHigh = ( sampleCellId > id );
        high = isHigh ? idx - 1 : high;
        bool isLow = ( sampleCellId < id );
        low = isLow ? idx + 1 : low;
        bool isMiddle = !( isHigh || isLow );

        bool zeroCase = ( idx == 0 && isMiddle );
        int sampleM1CellId = zeroCase ? -1 : PI_CELL_ID( sampleMinus1 );
        converged = isMiddle && ( zeroCase || sampleM1CellId < sampleCellId );
        cellIndex = converged ? idx : cellIndex;
        high = ( isMiddle && !converged ) ? idx - 1 : high;
    }//while

    gridCellIndex[ id ] = cellIndex;
}

__kernel void sortPostPass(
    __global uint2 * particleIndex,
    __global uint  * particleIndexBack,
    __global float4 * position,
    __global float4 * velocity,
    __global float4 * sortedPosition,
    __global float4 * sortedVelocity,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if(id==3500)
    {
        id = id;
    }
    if( id >= PARTICLE_COUNT ) return;
    uint2 spi = particleIndex[ id ];//contains id of cell and id of particle it has sorted
    int serialId = PI_SERIAL_ID( spi );//get a particle Index
    int cellId = PI_CELL_ID( spi );//get a cell Index
    float4 position_ = position[ serialId ];//get position by serialId
    POSITION_CELL_ID( position_ ) = (float)cellId;
    float4 velocity_ = velocity[ serialId ];
    sortedVelocity[ id ] = velocity_;//put velocity to sortedVelocity for right order according to particleIndex
    sortedPosition[ id ] = position_;//put position to sortedVelocity for right order according to particleIndex
    particleIndexBack[ serialId ] = id;
}

//=================================
// PCI SPH KERNELS BELOW
//=================================

__kernel void pcisph_computeDensity(
    __global float2 * neighborMap,
    double Wpoly6Coefficient,
    float h,
    float mass,
    float rho0,
    float simulationScale,
    float stiffness,
    __global float4 * sortedPosition,
    __global float * pressure,
    __global float * rho,
    __global uint * particleIndexBack,
    float delta,
    int PARTICLE_COUNT )
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;
    id = particleIndexBack[id];//track selected particle (indices are not shuffled anymore)
    int idx = id * MAX_NEIGHBOR_COUNT;
    int nc=0;//neighbor counter
    /*float*/
    double density = 0.0f;
    float r_ij2;//squared r_ij
    float hScaled = h * simulationScale;//scaled smoothing radius
    float hScaled2 = hScaled*hScaled;//squared scaled smoothing radius
    float hScaled6 = hScaled2*hScaled2*hScaled2;
    float2 nm;
    int real_nc = 0;

    do// gather density contribution from all neighbors (if they exist)
    {
        if( NEIGHBOR_MAP_ID( neighborMap[ idx + nc ] ) != NO_PARTICLE_ID )
        {
            r_ij2= NEIGHBOR_MAP_DISTANCE( neighborMap[ idx + nc ] );	// distance is already scaled here
            r_ij2 *= r_ij2;
            density += (hScaled2-r_ij2)*(hScaled2-r_ij2)*(hScaled2-r_ij2);
            real_nc++;
        }

    }
    while( ++nc < MAX_NEIGHBOR_COUNT );

    if(density<hScaled6) density = hScaled6;

    density *= ((double)mass)*Wpoly6Coefficient; // since all particles are same fluid type, factor this out to here
    rho[ id ] = density;
}

__kernel void pcisph_computeForcesAndInitPressure(
    __global float2 * neighborMap,
    __global float * rho,
    __global float  * pressure,
    __global float4 * sortedPosition,
    __global float4 * sortedVelocity,
    __global float4 * acceleration,
    __global uint * particleIndexBack,
    float surfTensCoeff,
    double del2WviscosityCoefficient,
    float h,
    float mass,
    float mu,
    float simulationScale,
    float gravity_x,
    float gravity_y,
    float gravity_z,
    __global float4 * position,
    __global uint2 * particleIndex,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;
    id = particleIndexBack[id];//track selected particle (indices are not shuffled anymore)
    int id_source_particle = PI_SERIAL_ID( particleIndex[id] );
    if((int)(position[ id_source_particle ].w) == BOUNDARY_PARTICLE)
    {
        //FOR BOUNDARY PARTICLE WE SHOULDN'T COMPUTE ACCELERATION BECAUSE THEY DON'T MOVE
        acceleration[ id ] = (float4)(0.0f, 0.0f, 0.0f, 0.0f );
        acceleration[ PARTICLE_COUNT+id ] = (float4)(0.0f, 0.0f, 0.0f, 0.0f );
        pressure[id] = 0.f;//initialize pressure with 0
        return;
    }
    int idx = id * MAX_NEIGHBOR_COUNT;
    float hScaled = h * simulationScale;
    float hScaled2 = hScaled*hScaled;//29aug_A.Palyanov

    float4 acceleration_i;
    float2 nm;
    float r_ij;
    int nc = 0;//neighbor counter
    int jd;
    float4 sum = (float4)( 0.0f, 0.0f, 0.0f, 0.0f );
    float4 vi,vj;
    float4 accel_surfTensForce = (float4)( 0.0f, 0.0f, 0.0f, 0.0f );

    do
    {

        if( (jd = NEIGHBOR_MAP_ID(neighborMap[ idx + nc])) != NO_PARTICLE_ID )
        {
            r_ij = NEIGHBOR_MAP_DISTANCE( neighborMap[ idx + nc] );

            if(r_ij<hScaled)
            {
                float rho_i;
                float rho_j;
                //neighbor_cnt++;
                rho_i = rho[id];
                rho_j = rho[jd];
                vi = sortedVelocity[id];
                vj = sortedVelocity[jd];
                sum += (sortedVelocity[jd]-sortedVelocity[id])*(hScaled-r_ij)/rho[jd];
                //29aug_A.Palyanov_start_block
                // M.Beckner & M.Teschner / Weakly compressible SPH for free surface flows. 2007.
                //normalVector += sortedPosition[id]-sortedPosition[jd];
                //	-0.3f * (sortedPosition[id]-sortedPosition[jd])*simulationScale * pow(hScaled2/2/*-r_ij*r_ij*/,3);
                //29aug_A.Palyanov_end_block
                //0.09 for experiments with water drops
                //-0.0133
                // surface tension force
                accel_surfTensForce += surfTensCoeff * (sortedPosition[id]-sortedPosition[jd]);
            }
        }

    }
    while(  ++nc < MAX_NEIGHBOR_COUNT );

    accel_surfTensForce.w = 0.f;

    // mu = viscosity

    sum *= (float)(mass * mu) * (float)(del2WviscosityCoefficient/rho[id]);

    // apply external forces
    acceleration_i = sum;

    acceleration_i += (float4)( gravity_x, gravity_y, gravity_z, 0.0f );

    acceleration_i +=  accel_surfTensForce; //29aug_A.Palyanov

    acceleration[ id ] = acceleration_i;

    // 1st half of 'acceleration' array is used to store acceleration corresponding to gravity, visc. force etc.
    acceleration[ PARTICLE_COUNT+id ] = (float4)(0.0f, 0.0f, 0.0f, 0.0f );
    // 2nd half of 'acceleration' array is used to store pressure force

    pressure[id] = 0.f;//initialize pressure with 0

}
__kernel void pcisph_computeElasticForces(
    __global float2 * neighborMap,
    __global float4 * sortedPosition,
    __global float4 * sortedVelocity,
    __global float4 * acceleration,
    __global uint * particleIndexBack,
    __global float4 * velocity,
    float h,
    float mass,
    float simulationScale,
    int numOfElasticP,
    __global float4 * elasticConnectionsData,
    int offset,
    int PARTICLE_COUNT,
    int MUSCLE_COUNT,
    __global float * muscle_activation_signal,
    __global float4 * position
)
{
    int index = get_global_id( 0 );//it is the index of the elastic particle among all elastic particles but this isn't real id of particle

    if(index>=numOfElasticP)
    {
        return;
    }
    int nc = 0;

    float4 p_xyzw = position[index];

    int id = particleIndexBack[index + offset];
    int idx = index * MAX_NEIGHBOR_COUNT;
    float r_ij_equilibrium, r_ij, delta_r_ij, v_i_cm_length;
    float k = 600000000.f;// k - coefficient of elasticity
    float4 vect_r_ij;
    float4 centerOfMassVelocity;
    float4 velocity_i_cm;
    float check;
    float4 proj_v_i_cm_on_r_ij;
    float4 velocity_i = velocity[id];//velocity[ index + offset ];
    float4 velocity_j;
    int jd;
    int i;
    float4 iPos,jPos;


    iPos = sortedPosition[id];

    do
    {
        if( (jd = (int)elasticConnectionsData[ idx + nc ].x) != NO_PARTICLE_ID )
        {
            jd = particleIndexBack[jd];
            velocity_j = velocity[ jd ];

            jPos = sortedPosition[jd];

            r_ij_equilibrium = elasticConnectionsData[ idx + nc ].y;//rij0
            vect_r_ij = (sortedPosition[id] - sortedPosition[jd]) * simulationScale;
            vect_r_ij.w = 0;

            r_ij = sqrt(DOT(vect_r_ij,vect_r_ij));
            delta_r_ij = r_ij - r_ij_equilibrium;

            if(r_ij!=0.f)
            {
                acceleration[ id ] += -(vect_r_ij/r_ij) * delta_r_ij * k;

                for(i=0; i<MUSCLE_COUNT; i++) //check all muscles
                {
                    if((int)(elasticConnectionsData[idx+nc].z)==(i+1))//contractible spring, = muscle
                    {
                        if(muscle_activation_signal[i]>0.f)
                            acceleration[ id ] += -(vect_r_ij/r_ij) * muscle_activation_signal[i] * 800.f;
                    }
                }
            }

            centerOfMassVelocity = (velocity_i + velocity_j)/2.f;
            velocity_i_cm = velocity_i - centerOfMassVelocity;
            velocity_i_cm.w = 0.f;
            v_i_cm_length = sqrt( DOT (velocity_i_cm,velocity_i_cm) );

            if((v_i_cm_length!=0)&&(r_ij!=0))
            {
                proj_v_i_cm_on_r_ij = vect_r_ij * DOT(velocity_i_cm,vect_r_ij)/(r_ij*r_ij);

            }
        }
        else
            break;//once we meet NO_PARTICLE_ID in the list of neighbours, it means that all the rest till the end are also NO_PARTICLE_ID
    }
    while( ++nc < MAX_NEIGHBOR_COUNT );

    return;
}
// Boundary handling, according to the following article:
// M. Ihmsen, N. Akinci, M. Gissler, M. Teschner, Boundary Handling and Adaptive Time-stepping for PCISPH Proc. VRIPHYS, Copenhagen, Denmark, pp. 79-88, Nov 11-12, 2010.
// short citation: Ihmsen et. al., 2010
// The article chapter 3.2 describes new boundary method that combines the idea of direct-forcing [BTT09]
// with the pressure-based frozen-particles method. The proposed boundary method enforces non-penetration
// of rigid objects even for large time steps. By incorporating density estimates at the boundary into the
// pressure force, unnatural accelerations resulting from high pressure ratios are avoided.

void computeInteractionWithBoundaryParticles(
    int id,
    float r0,
    __global float2 * neighborMap,
    __global uint * particleIndexBack,
    __global uint2 * particleIndex,
    __global float4 * position,
    __global float4 * velocity,
    float4 * pos_,
    bool tangVel,
    float4 * vel,
    int PARTICLE_COUNT
)
{
    //track selected particle (indices are not shuffled anymore)
    int idx = id * MAX_NEIGHBOR_COUNT;
    int id_b;//index of id's particle neighbour which is a boundary particle
    int id_b_source_particle, nc = 0;
    float4 n_c_i = (float4)(0.f,0.f,0.f,0.f);
    float4 n_b;
    float w_c_ib, w_c_ib_sum = 0.f, w_c_ib_second_sum = 0.f;
    float4 delta_pos;
    float n_c_i_length,x_ib_dist;

    do// gather density contribution from all neighbors (if they exist)
    {
        if( (id_b = NEIGHBOR_MAP_ID( neighborMap[ idx + nc ])) != NO_PARTICLE_ID )
        {
            id_b_source_particle = PI_SERIAL_ID( particleIndex[id_b] );
            if((int)position[id_b_source_particle].w == BOUNDARY_PARTICLE)
            {
                x_ib_dist  = ((*pos_).x - position[id_b_source_particle].x) * ((*pos_).x - position[id_b_source_particle].x);
                x_ib_dist += ((*pos_).y - position[id_b_source_particle].y) * ((*pos_).y - position[id_b_source_particle].y);
                x_ib_dist += ((*pos_).z - position[id_b_source_particle].z) * ((*pos_).z - position[id_b_source_particle].z);
                x_ib_dist = SQRT(x_ib_dist);
                w_c_ib = max(0.f,(r0-x_ib_dist)/r0);			//Ihmsen et. al., 2010, page 4, formula (10)
                n_b = velocity[id_b_source_particle];			//ATTENTION! for boundary, non-moving particles velocity has no sense, but instead we need to store normal vector. We keep it in velocity data structure for memory economy.
                n_c_i += n_b * w_c_ib;							//Ihmsen et. al., 2010, page 4, formula (9)
                w_c_ib_sum += w_c_ib;							//Ihmsen et. al., 2010, page 4, formula (11), sum #1
                w_c_ib_second_sum += w_c_ib * (r0 - x_ib_dist); //Ihmsen et. al., 2010, page 4, formula (11), sum #2
            }
        }
    }
    while( ++nc < MAX_NEIGHBOR_COUNT );

    n_c_i_length = DOT(n_c_i,n_c_i);
    if(n_c_i_length != 0)
    {
        n_c_i_length = sqrt(n_c_i_length);
        delta_pos = ((n_c_i/n_c_i_length)*w_c_ib_second_sum)/w_c_ib_sum;	//
        (*pos_).x += delta_pos.x;								//
        (*pos_).y += delta_pos.y;								// Ihmsen et. al., 2010, page 4, formula (11)
        (*pos_).z += delta_pos.z;								//
        if(tangVel) // tangential component of velocity
        {
            float vel_n_len = n_c_i.x * (*vel).x + n_c_i.y * (*vel).y + n_c_i.z * (*vel).z;
            if(vel_n_len < 0)
            {
                float eps = 0.99f; //eps should be <= 1.0			// controls the friction of the collision
                (*vel).x -= n_c_i.x * vel_n_len;
                (*vel).y -= n_c_i.y * vel_n_len;
                (*vel).z -= n_c_i.z * vel_n_len;
                (*vel) = (*vel) * eps;							// Ihmsen et. al., 2010, page 4, formula (12)
            }
        }
    }
}
//
__kernel void pcisph_predictPositions(
    __global float4 * acceleration,
    __global float4 * sortedPosition,
    __global float4 * sortedVelocity,
    __global uint2 * particleIndex,
    __global uint * particleIndexBack,
    float gravity_x,
    float gravity_y,
    float gravity_z,
    float simulationScaleInv,
    float timeStep,
    float xmin,
    float xmax,
    float ymin,
    float ymax,
    float zmin,
    float zmax,
    float damping,
    __global float4 * position,
    __global float4 * velocity,
    float r0,
    __global float2 * neighborMap,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;
    id = particleIndexBack[id];
    int id_source_particle = PI_SERIAL_ID( particleIndex[id] );
    float4 position_ = sortedPosition[ id ];
    if((int)(position[ id_source_particle ].w) == 3) //stationary (boundary) particles, right?
    {
        sortedPosition[PARTICLE_COUNT+id] = position_;//this line was missing (absent) and this fact caused serions errors in program behavior
        return;
    }
    //                     pressure force (dominant)            + all other forces
    float4 acceleration_ = acceleration[ PARTICLE_COUNT+id ];// + acceleration[ id ];
    float4 velocity_ = sortedVelocity[ id ];
    // Semi-implicit Euler integration
    float4 newVelocity_ = velocity_ + timeStep * acceleration_; //newVelocity_.w = 0.f;
    float posTimeStep = timeStep * simulationScaleInv;
    float4 newPosition_ = position_ + posTimeStep * newVelocity_; //newPosition_.w = 0.f;

    sortedPosition[PARTICLE_COUNT+id] = newPosition_;// in current version sortedPosition array has double size,

}


__kernel void pcisph_predictDensity(
    __global float2 * neighborMap,
    __global uint * particleIndexBack,
    double Wpoly6Coefficient,
    float h,
    float mass,
    float rho0,
    float simulationScale,
    float stiffness,
    __global float4 * sortedPosition,
    __global float * pressure,
    __global float * rho,
    float delta,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;
    id = particleIndexBack[id];//track selected particle (indices are not shuffled anymore)
    int idx = id * MAX_NEIGHBOR_COUNT;
    int nc=0;//neighbor counter
    double density = 0.0f;
    float density_accum;
    float4 r_ij;
    float r_ij2;
    float h2 = h*h;
    float hScaled = h * simulationScale;//scaled smoothing radius
    float hScaled2 = hScaled*hScaled;//squared scaled smoothing radius
    float hScaled6 = hScaled2*hScaled2*hScaled2;
    int jd;


    do// gather density contribution from all neighbors (if they exist)
    {
        if( (jd = NEIGHBOR_MAP_ID( neighborMap[ idx + nc ])) != NO_PARTICLE_ID )
        {
            r_ij = sortedPosition[PARTICLE_COUNT+id]-sortedPosition[PARTICLE_COUNT+jd];
            r_ij2 = (r_ij.x*r_ij.x+r_ij.y*r_ij.y+r_ij.z*r_ij.z);

            if(r_ij2<h2)
            {
                density_accum += (h2-r_ij2)*(h2-r_ij2)*(h2-r_ij2);
            }

            if(r_ij2==0)
            {
                //printf("\a\n");
                printf("@@@|>>[%d]-[%d]<<|@@@ %E @@@@ (%f) (%f) ####",id,jd,((double)r_ij2),sortedPosition[PARTICLE_COUNT+id].w,sortedPosition[PARTICLE_COUNT+jd].w );
            }
        }

    }
    while( ++nc < MAX_NEIGHBOR_COUNT );

    density = (double)density_accum * simulationScale * simulationScale * simulationScale * simulationScale * simulationScale * simulationScale;
    if(density<hScaled6)
    {
        density = hScaled6;
    }


    density *= ((double)mass)*Wpoly6Coefficient; // since all particles are same fluid type, factor this out to here
    rho[ PARTICLE_COUNT+id ] = (float)density;
}


__kernel void pcisph_correctPressure(
    __global float2 * neighborMap,
    __global uint * particleIndexBack,
    float h,
    float mass,
    float rho0,
    float simulationScale,
    float stiffness,
    __global float4 * sortedPosition,
    __global float * pressure,
    __global float * rho,
    float delta,
    __global float4 * position,
    __global uint2 * particleIndex,
    int PARTICLE_COUNT
)
{

    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;
    id = particleIndexBack[id];//track selected particle (indices are not shuffled anymore)
    int idx = id * MAX_NEIGHBOR_COUNT;
    int nc = 0;// neigbor counter
    float rho_err;
    float p_corr;


    rho_err = rho[PARTICLE_COUNT+id] - rho0;
    p_corr = rho_err*delta;
    if(p_corr < 0) p_corr = 0;//non-negative pressure
    pressure[ id ] += p_corr;

}


__kernel void pcisph_computePressureForceAcceleration(
    __global float2 * neighborMap,
    __global float * pressure,
    __global float * rho,
    __global float4 * sortedPosition,
    __global float4 * sortedVelocity,
    __global uint * particleIndexBack,
    float delta,
    double gradWspikyCoefficient,
    float h,
    float mass,
    float mu,
    float simulationScale,
    __global float4 * acceleration,
    float rho0,
    __global float4 * position,
    __global uint2 * particleIndex,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if( id >= PARTICLE_COUNT ) return;
    id = particleIndexBack[id];//track selected particle (indices are not mixed anymore)
    int id_source_particle = PI_SERIAL_ID( particleIndex[id] );
    if((int)(position[ id_source_particle ].w) == BOUNDARY_PARTICLE)
    {
        acceleration[ PARTICLE_COUNT+id ] = 0.f;
        return;
    }
    int idx = id * MAX_NEIGHBOR_COUNT;
    float hScaled = h * simulationScale;

    float pressure_i  = pressure[ id ];
    float rho_i		  = rho[ PARTICLE_COUNT+id ];

    float4 result = (float4)( 0.0f, 0.0f, 0.0f, 0.0f );

    int nc=0;
    float4 gradW_ij;
    float r_ij,rho_err;
    float4 vr_ij;
    int jd;
    float value;
    int real_neighbors = 0;
    int total_neighbors = 0;

    do
    {
        if( (jd = NEIGHBOR_MAP_ID( neighborMap[ idx + nc ])) != NO_PARTICLE_ID)
        {
            r_ij = NEIGHBOR_MAP_DISTANCE( neighborMap[ idx + nc] );

            if(r_ij<hScaled)
            {
                value = -(hScaled-r_ij)*(hScaled-r_ij)*0.5f*(pressure[id]+pressure[jd])/rho[PARTICLE_COUNT+jd];
                vr_ij = (sortedPosition[id]-sortedPosition[jd])*simulationScale;
                vr_ij.w = 0;


                if(r_ij<0.5*(hScaled/2))//hScaled/2 = r0
                {
                    value = -(hScaled*0.25f-r_ij)*(hScaled*0.25f-r_ij)*0.5f*(rho0*delta)/rho[PARTICLE_COUNT+jd];
                }
                if(r_ij==0.0f)
                {
                    printf("\n> Error!: r_ij: %f ",r_ij);
                    printf("\n> sortedPosition[%d]	: %f , %f , %f ",id,sortedPosition[id].x,sortedPosition[id].y,sortedPosition[id].z);
                    printf("\n> sortedPosition[%d]	: %f , %f , %f ",jd,sortedPosition[jd].x,sortedPosition[jd].y,sortedPosition[jd].z);
                }
                result += value*vr_ij/r_ij;

                // according to formula (3.3) in B. Solenthaler's dissertation "Incompressible Fluid Simulation and Advanced Surface Handling with SPH"
                // http://www.ifi.uzh.ch/pax/uploads/pdf/publication/1299/Solenthaler.pdf

                real_neighbors++;
            }

            total_neighbors++;
        }

    }
    while( ++nc < MAX_NEIGHBOR_COUNT );

    /*1*/
    result *= (float)( ((double)mass)*gradWspikyCoefficient/((double)rho[PARTICLE_COUNT+id]) );
    /*2*///result *= mass*gradWspikyCoefficient;
    acceleration[ PARTICLE_COUNT+id ] = result; 

}

__kernel void clearMembraneBuffers(
    __global float4 * position,
    __global float4 * velocity,
    __global float4 * sortedPosition,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if(id>=PARTICLE_COUNT) return;

    position[PARTICLE_COUNT + id] = (float4)(0,0,0,0); //extra memory to store changes in considered particles's coordinates due to interaction with membranes. Need to make it zero every step.
    velocity[PARTICLE_COUNT + id] = (float4)(0,0,0,0); //extra memory to store changes in considered particles's   velocity  due to interaction with membranes. Need to make it zero every step.
    //sortedPosition[PARTICLE_COUNT*2 + id] = (float4)(0,0,0,0);
}

float calcDeterminant3x3(float4 c1, float4 c2, float4 c3)
{
    // here we expect the following structure of input vectors (0-th component of each is not used, 1,2,3 - used)
//  [c1]: c11  c12  c13
//  [c2]: c21  c22  c23
//  [c3]: c31  c32  c33
//  by the way, result for transposed matrix will be equal to the original one

    return  c1.x*c2.y*c3.z + c1.y*c2.z*c3.x + c1.z*c2.x*c3.y
            - c1.z*c2.y*c3.x - c1.x*c2.z*c3.y - c1.y*c2.x*c3.z;

}


float4 calculateProjectionOfPointToPlane(float4 ps, float4 pa, float4 pb, float4 pc)
{
    // ps - point to project on the plane; pa-pb-pc - vertices of the triangle defining the plane

    float4 pm = (float4)(0,0,0,0);//projection of ps on pa-pb-pc plane
    float denominator;
    //  b  a_2 a_3   a_1
    // |b1 a12 a13|  a11
    // |b2 a22 a23|  a21
    // |b3 a32 a33|  a31

    float b_1 = pa.x*((pb.y-pa.y)*(pc.z-pa.z)-(pb.z-pa.z)*(pc.y-pa.y))
                + pa.y*((pb.z-pa.z)*(pc.x-pa.x)-(pb.x-pa.x)*(pc.z-pa.z))
                + pa.z*((pb.x-pa.x)*(pc.y-pa.y)-(pb.y-pa.y)*(pc.x-pa.x));
    float b_2 = ps.x*(pb.x-pa.x)+ps.y*(pb.y-pa.y)+ps.z*(pb.z-pa.z);
    float b_3 = ps.x*(pc.x-pa.x)+ps.y*(pc.y-pa.y)+ps.z*(pc.z-pa.z);

    float a_1_1 = (pb.y-pa.y)*(pc.z-pa.z)-(pb.z-pa.z)*(pc.y-pa.y);
    float a_1_2 = pb.x - pa.x;
    float a_1_3 = pc.x - pa.x;

    float a_2_1 = (pb.z-pa.z)*(pc.x-pa.x)-(pb.x-pa.x)*(pc.z-pa.z);
    float a_2_2 = pb.y - pa.y;
    float a_2_3 = pc.y - pa.y;

    float a_3_1 = (pb.x-pa.x)*(pc.y-pa.y)-(pb.y-pa.y)*(pc.x-pa.x);
    float a_3_2 = pb.z - pa.z;
    float a_3_3 = pc.z - pa.z;

    float4 a_1 = (float4)(a_1_1, a_1_2, a_1_3, 0);
    float4 a_2 = (float4)(a_2_1, a_2_2, a_2_3, 0);
    float4 a_3 = (float4)(a_3_1, a_3_2, a_3_3, 0);
    float4 b = (float4)(b_1, b_2, b_3, 0);

    denominator = calcDeterminant3x3(a_1,a_2,a_3);

    if(denominator!=0)
    {
        pm.x = calcDeterminant3x3(b  ,a_2,a_3)/denominator;
        pm.y = calcDeterminant3x3(a_1,b  ,a_3)/denominator;
        pm.z = calcDeterminant3x3(a_1,a_2,b  )/denominator;
    }
    else
    {
        printf("\ndenominator equal to zero\n");
        pm.w = -1;//indicates error
    }


    return pm;
}

float calculateTriangleSquare(float4 v1, float4 v2, float4 v3)
{
    // here 'v' is for vertex or vector, anyway v1, v2, v3 are coordinates of 3 points in 3D.
    // 4-th coordinate is not used
    // first calc 2 vectors: v21 and v31
    float4 a = v2 - v1;//v21
    float4 b = v3 - v1;//v31
    //vector product of them
    float4 ab = (float4)(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x, 0);
    return sqrt(ab.x*ab.x+ab.y*ab.y+ab.z*ab.z)/2.f;
}

__kernel void computeInteractionWithMembranes(
    __global float4 * position,
    __global float4 * velocity,
    __global float4 * sortedPosition,
    __global uint2 * particleIndex,
    __global uint * particleIndexBack,
    __global float2 * neighborMap,
    __global int * particleMembranesList,
    __global int * membraneData,
    int PARTICLE_COUNT,
    int numOfElasticP,
    float r0 )
{
    int id = get_global_id( 0 );
    if(id>=PARTICLE_COUNT) return;

    id = particleIndexBack[id];

    int id_source_particle = PI_SERIAL_ID( particleIndex[id] );
    int jd_source_particle;

    //float4 position_ = sortedPosition[ id ];
    float4 position_ = position[ id ];

    if((int)(position[ id_source_particle ].w) == BOUNDARY_PARTICLE) return;

    if((int)(position[ id_source_particle ].w) != LIQUID_PARTICLE) return;	//!!! currently we consider only liquid particles
    //!!! interacting with membranes

    int jd, idx = id * MAX_NEIGHBOR_COUNT;
    int mdi;//membraneData index
    int i,j,k;//these i and j have nothing in common with id and jd indexes
    int i_sp,j_sp,k_sp;
    float4 pos_i,pos_j,pos_k;
    float4 pos_p;//position of id-particle projection on membrane plane;
    float4 normal_to_ijk_plane;
    float  normal_to_ijk_plane_length;
    float4 vector_id_jd;
    float4 normal_vector_final = (float4)(0,0,0,0);
    float4 membrane_jd_normal_vector [MAX_NEIGHBOR_COUNT];
    float  _distance_id_jd;
    float  distance_id_jd [MAX_NEIGHBOR_COUNT];
    int    membrane_jd [MAX_NEIGHBOR_COUNT];
    int	   membrane_jd_counter = 0;
    int    membrane_ijk_counter = 0;

    for(i=0; i<MAX_NEIGHBOR_COUNT; i++)
    {
        membrane_jd_normal_vector[i] = (float4)(0,0,0,0);
        //membrane_jd[i] = -1;
    }

    //check all neighbours of each particle to find those which belong to membranes.
    //particleMembranesList(size:numOfElasticP*MAX_MEMBRANES_INCLUDING_SAME_PARTICLE)
    //was introduced to provide this possibility. The same order of indexes as in <position> buffer

    for(int nc=0; nc<MAX_NEIGHBOR_COUNT; nc++)//nc - neighbour counter
    {
        //search for membrane particles through all id-th particle neighbours
        if( (jd = NEIGHBOR_MAP_ID( neighborMap[ idx + nc ])) != NO_PARTICLE_ID)
        {
            jd_source_particle = PI_SERIAL_ID( particleIndex[jd] );

            // in position[] memory elastic matter particles are allocated first, then liquid, and finally border
            if((int)(position[ jd_source_particle ].w) == ELASTIC_PARTICLE)	//in current version only elastic
            {
                //matter particles can compose membranes
                membrane_ijk_counter = 0;
                vector_id_jd = position[id_source_particle] - position[jd_source_particle];
                vector_id_jd.z = 0; //mv change from subscripting
                _distance_id_jd = sqrt(dot(vector_id_jd,vector_id_jd));
                // elastic matter particles have no information
                // about participation in membrane composition
                // Let's get it - check corresponding position of particleMembranesList (if it is non-empty)
                for(int mli=0; mli<MAX_MEMBRANES_INCLUDING_SAME_PARTICLE; mli++)
                {
                    //search through the list of elementary triangular membranes at least one corner of which is current neighbor particle
                    if((mdi=particleMembranesList[jd_source_particle*MAX_MEMBRANES_INCLUDING_SAME_PARTICLE+mli])>-1)
                    {
                        i = membraneData[mdi*3+0];
                        j = membraneData[mdi*3+1];
                        k = membraneData[mdi*3+2];

                        pos_i = position[i];
                        pos_j = position[j];
                        pos_k = position[k];

                        pos_p = calculateProjectionOfPointToPlane(position[ id_source_particle ],pos_i,pos_j,pos_k);

                        if(pos_p.w==-1)
                        {
                            printf("calculateProjectionOfPointToPlane() returned error");
                            return;
                        }

                        // two points: 'position[ jd_source_particle ]' and its projection on i-j-k plane 'pos_p'
                        // are enough to calc normal vector to i-j-k plane:

                        normal_to_ijk_plane = position[ id_source_particle ] - pos_p;
                        normal_to_ijk_plane_length =   sqrt(normal_to_ijk_plane.x*normal_to_ijk_plane.x +
                                                            normal_to_ijk_plane.y*normal_to_ijk_plane.y +
                                                            normal_to_ijk_plane.z*normal_to_ijk_plane.z);
                        if(normal_to_ijk_plane_length>0)
                        {
                            normal_to_ijk_plane /= normal_to_ijk_plane_length;// normalized now

                            membrane_jd_normal_vector[membrane_jd_counter] += normal_to_ijk_plane;
                            membrane_ijk_counter++;

                            // so, we consider i-th particle and a number of its neighbours which belong to membrane(s).
                            // normal vectors are calculated for all of them.
                            // now it's time to calculate forces:
                            // 1) force F_i, acting on i-th particle
                            // 2) force -F_i, distributed over neighbor membrane particles
                            // Interaction causes change of coordinates of all interacting particles
                            // We'll accumulate changes in position[PARTICLE_COUNT+i], and only after all particles are processed, we'll apply these changes.

                        }
                        else
                        {
                            printf("computeInteractionWithMembranes error #001");
                            return;
                        }


                        // ok, we finally have projection of considered particle on the plane of i-j-k triangle.
                        // If triangle's square >0 and if projection point is inside the triangle (not outside)
                        // then this triangle is located is such way that we have to take it into account and
                        // calculate repulsion from it.

                    }
                    else break;
                }

                if(membrane_ijk_counter>0)
                {
                    membrane_jd_normal_vector [membrane_jd_counter] /= (float)membrane_ijk_counter;
                    distance_id_jd [membrane_jd_counter] = _distance_id_jd;
                    membrane_jd [membrane_jd_counter] = jd_source_particle;
                    membrane_jd_counter++;
                }

                //here for pair id - jd summary normal vector for jd particle (if it belongs to membrane) is already calculated and we can use it

            }
        }
        else break;
    }

    if(membrane_jd_counter>0)
    {
        int nc = 0;
        float4 n_c_i = (float4)(0.f,0.f,0.f,0.f);
        float4 n_m;
        float w_c_im, w_c_im_sum = 0.f, w_c_im_second_sum = 0.f;
        float4 delta_pos;
        float4 velocity_membrane_average = (float4)(0.f,0.f,0.f,0.f);
        float n_c_i_length,x_im_dist;
        int id_m_source_particle;//index of i-th particle's (current) neighbours which are membrane particles
        // they are already in the list <membrane_jd>

        // gather density contribution from all neighbors (if they exist)
        do
        {
            id_m_source_particle = membrane_jd[nc];
            x_im_dist = distance_id_jd[nc];
            w_c_im = max(0.f,(r0-x_im_dist)/r0);			//Ihmsen et. al., 2010, page 4, formula (10)
            n_m = membrane_jd_normal_vector[nc];
            n_c_i += n_m * w_c_im;							//Ihmsen et. al., 2010, page 4, formula (9)
            w_c_im_sum += w_c_im;							//Ihmsen et. al., 2010, page 4, formula (11), sum #1
            w_c_im_second_sum += w_c_im * (r0 - x_im_dist); //Ihmsen et. al., 2010, page 4, formula (11), sum #2

            velocity_membrane_average += velocity[PARTICLE_COUNT+id_m_source_particle];

        }
        while( ++nc < membrane_jd_counter );

        n_c_i.w = 0;
        n_c_i_length = DOT(n_c_i,n_c_i);

        if(n_c_i_length != 0)
        {
            //change of coordinates for id_source_particle
            n_c_i_length = sqrt(n_c_i_length);
            delta_pos = 1.0f*((n_c_i/n_c_i_length)*w_c_im_second_sum)/w_c_im_sum;	//
            position[PARTICLE_COUNT+id_source_particle].x += delta_pos.x;		//
            position[PARTICLE_COUNT+id_source_particle].y += delta_pos.y;		// Ihmsen et. al., 2010, page 4, formula (11)
            position[PARTICLE_COUNT+id_source_particle].z += delta_pos.z;		//

            velocity_membrane_average += velocity[PARTICLE_COUNT+id_source_particle];
            velocity_membrane_average /= (float)(membrane_jd_counter+1);

        }

    }
}

__kernel void computeInteractionWithMembranes_finalize(
    __global float4 * position,
    __global float4 * velocity,
    __global uint2 * particleIndex,
    __global uint * particleIndexBack,
    int PARTICLE_COUNT
)
{
    int id = get_global_id( 0 );
    if(id>=PARTICLE_COUNT) return;

    id = particleIndexBack[id];

    int id_source_particle = PI_SERIAL_ID( particleIndex[id] );
    int jd_source_particle;
    float4 position_ = position[ id ];
    float v2;

    if((int)(position[ id_source_particle ].w) == BOUNDARY_PARTICLE) return;
    //!!! interacting with membranes
    position[ id_source_particle ] += position[ PARTICLE_COUNT + id_source_particle ];

}

__kernel void pcisph_integrate(
    __global float4 * acceleration,
    __global float4 * sortedPosition,
    __global float4 * sortedVelocity,
    __global uint2 * particleIndex,
    __global uint * particleIndexBack,
    float gravity_x,
    float gravity_y,
    float gravity_z,
    float simulationScaleInv,
    float timeStep,
    float xmin,
    float xmax,
    float ymin,
    float ymax,
    float zmin,
    float zmax,
    float damping,
    __global float4 * position,
    __global float4 * velocity,
    __global float * rho,
    float r0,
    __global float2 * neighborMap,
    int PARTICLE_COUNT,
    int iterationCount
)
{
    int id = get_global_id( 0 );
    if(id>=PARTICLE_COUNT) return;
    id = particleIndexBack[id];
    int id_source_particle = PI_SERIAL_ID( particleIndex[id] );
    float4 position_ = sortedPosition[ id ];
    if((int)(position[ id_source_particle ].w) == BOUNDARY_PARTICLE)
    {
        return;
    }
    float4  accelOld = acceleration[ id ];
    float4  accelT = acceleration[ PARTICLE_COUNT+id ];
    float4 acceleration_ = acceleration[ id ] + acceleration[ PARTICLE_COUNT+id ];
    acceleration_.w = 0.f;
    float4 velocity_ = sortedVelocity[ id ];
    float4 newVelocity_ = velocity_ + timeStep * acceleration_  ; //newVelocity_.w = 0.f;

    float posTimeStep = timeStep * simulationScaleInv;
    float4 newPosition_ = position_ + posTimeStep * newVelocity_; //newPosition_.w = 0.f;

    // in Chao Fang realization here is also acceleration 'speed limit' applied

    if(newPosition_.x<xmin) newPosition_.x = xmin;//A.Palyanov 30.08.2012
    if(newPosition_.y<ymin) newPosition_.y = ymin;//A.Palyanov 30.08.2012
    if(newPosition_.z<zmin) newPosition_.z = zmin;//A.Palyanov 30.08.2012
    if(newPosition_.x>xmax-0.000001f) newPosition_.x = xmax-0.000001f;//A.Palyanov 30.08.2012
    if(newPosition_.y>ymax-0.000001f) newPosition_.y = ymax-0.000001f;//A.Palyanov 30.08.2012
    if(newPosition_.z>zmax-0.000001f) newPosition_.z = zmax-0.000001f;//A.Palyanov 30.08.2012

    float particleType = position[ id_source_particle ].w;
    newVelocity_ = (velocity_ + newVelocity_) * 0.5f ;
    computeInteractionWithBoundaryParticles(id,r0,neighborMap,particleIndexBack,particleIndex,position,velocity,&newPosition_, true, &newVelocity_,PARTICLE_COUNT);

    velocity[ id_source_particle ] = newVelocity_;//newVelocity_;
    position[ id_source_particle ] = newPosition_;
    position[ id_source_particle ].w = particleType;

}
