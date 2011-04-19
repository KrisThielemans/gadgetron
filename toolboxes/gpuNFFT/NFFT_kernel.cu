/*
  CUDA implementation of the NFFT.

  -----------

  Accelerating the Non-equispaced Fast Fourier Transform on Commodity Graphics Hardware.
  T.S. Sørensen, T. Schaeffter, K.Ø. Noe, M.S. Hansen. 
  IEEE Transactions on Medical Imaging 2008; 27(4):538-547.

  Real-time Reconstruction of Sensitivity Encoded Radial Magnetic Resonance Imaging Using a Graphics Processing Unit.
  T.S. Sørensen, D. Atkinson, T. Schaeffter, M.S. Hansen.
  IEEE Transactions on Medical Imaging 2009; 28(12): 1974-1985. 
*/

//
// There is no header file accompanying this kernel, so it makes most sense to read the code/file from the end and upwards
//

//
// Transfer result from shared memory to global memory.
//

template<class REAL> __inline__ __device__ void 
NFFT_output( unsigned int number_of_samples, unsigned int number_of_batches,
	     vectord<REAL,2> *samples,
	     unsigned int double_warp_size_power,
	     unsigned int globalThreadId, unsigned int sharedMemFirstSampleIdx )
{
  
  REAL *shared_mem = (REAL*) _shared_mem;
  
  for( unsigned int batch=0; batch<number_of_batches; batch++ ){
    vectord<REAL,2> sample_value;
    sample_value.vec[0] = shared_mem[sharedMemFirstSampleIdx+(batch<<double_warp_size_power)];
    sample_value.vec[1] = shared_mem[sharedMemFirstSampleIdx+(batch<<double_warp_size_power)+warpSize];
    samples[batch*number_of_samples+globalThreadId] = sample_value;
  }
}

template<unsigned int D> __inline__ __device__ void
resolve_wrap( vectord<int,D> &grid_position, vectord<int,D> &matrix_size_os )
{
  vectord<int,D> zero; to_vectord<int,D>(zero,0);
  grid_position += (vector_less<int,D>(grid_position, zero)*matrix_size_os);
  grid_position -= (vector_greater_equal<int,D>(grid_position, matrix_size_os)*matrix_size_os);
}

template<class REAL, unsigned int D> __inline__ __device__ void
NFFT_iterate_body( REAL alpha, REAL beta, REAL W,
		   vectord<unsigned int, D> matrix_size_os, vectord<unsigned int, D> fixed_dims,
		   unsigned int number_of_batches, 
		   vectord<REAL,2> *image,
		   unsigned int double_warp_size_power, REAL half_W, REAL one_over_W, vectord<REAL,D> matrix_size_os_real,
		   unsigned int sharedMemFirstSampleIdx,
		   vectord<REAL,D> sample_position, vectord<int,D> grid_position )
{
      
  // Calculate the distance between current sample and the grid cell
  vectord<REAL,D> grid_position_real; to_reald<REAL,int,D>(grid_position_real, grid_position);
  vectord<REAL,D> delta = abs(sample_position-grid_position_real);
  vectord<REAL,D> half_W_vec; to_vectord<REAL,D>( half_W_vec, half_W );
  
  // If cell too distant from sample then move on to the next cell
  //if( weak_greater(delta, half_W_vec ))
  //return;

  // Compute convolution weight.
  REAL weight = KaiserBessel<REAL>( delta, matrix_size_os_real, one_over_W, beta, fixed_dims );

  // Safety measure. We have occationally observed a NaN from the KaiserBessel computation
  if( !isfinite(weight) )
    return;

  // Resolve wrapping of grid position
  resolve_wrap<D>( grid_position, *((vectord<int,D>*)&matrix_size_os) );

  REAL *shared_mem = (REAL*) _shared_mem;
  
  for( unsigned int batch=0; batch<number_of_batches; batch++ ){
    
    // Read the grid cell value from global memory
    vectord<REAL,2> grid_value = image[batch*prod(matrix_size_os)+co_to_idx( *((vectord<unsigned int, D>*)&grid_position), matrix_size_os )];
    
    // Add 'weight*grid_value' to the samples in shared memory
    shared_mem[sharedMemFirstSampleIdx+(batch<<double_warp_size_power)] += (weight*grid_value.vec[0]);
    shared_mem[sharedMemFirstSampleIdx+(batch<<double_warp_size_power)+warpSize] += (weight*grid_value.vec[1]);
  }
}

//
// This method is deliberately overloaded in 'UINTd' (rather than templetized) to improve performance of the loop iteration
//

template<class REAL> __inline__ __device__ void
NFFT_iterate( REAL alpha, REAL beta, REAL W,
	      vectord<unsigned int,2> matrix_size_os, vectord<unsigned int,2> fixed_dims,
	      unsigned int number_of_batches, 
	      vectord<REAL,2> *image,
	      unsigned int double_warp_size_power, REAL half_W, REAL one_over_W, vectord<REAL,2> matrix_size_os_real,
	      unsigned int sharedMemFirstSampleIdx,
	      vectord<REAL,2> sample_position, vectord<int,2> lower_limit, vectord<int,2> upper_limit )
{
  
  // Iterate through all grid cells influencing the corresponding sample
  for( int y = lower_limit.vec[1]; y<=upper_limit.vec[1]; y++ ){
    for( int x = lower_limit.vec[0]; x<=upper_limit.vec[0]; x++ ){
      
      intd<2> grid_position;
      grid_position.vec[0] = x; grid_position.vec[1] = y;
      
      NFFT_iterate_body<REAL,2>( alpha, beta, W, matrix_size_os, fixed_dims, number_of_batches, image, double_warp_size_power, 
				 half_W, one_over_W, matrix_size_os_real, sharedMemFirstSampleIdx, sample_position, grid_position );
    }
  }
}

//
// This method is deliberately overloaded in 'd' (rather than templetized) to improve performance of the loop iteration
//

template<class REAL> __inline__ __device__ void
NFFT_iterate( REAL alpha, REAL beta, REAL W,
	      vectord<unsigned int,3> matrix_size_os, vectord<unsigned int,3> fixed_dims,
	      unsigned int number_of_batches, 
	      vectord<REAL,2> *image,
	      unsigned int double_warp_size_power, REAL half_W, REAL one_over_W, vectord<REAL,3> matrix_size_os_real, 
	      unsigned int sharedMemFirstSampleIdx,
	      vectord<REAL,3> sample_position, vectord<int,3> lower_limit, vectord<int,3> upper_limit )
{

  // Iterate through all grid cells influencing the corresponding sample
  for( int z = lower_limit.vec[2]; z<=upper_limit.vec[2]; z++ ){
    for( int y = lower_limit.vec[1]; y<=upper_limit.vec[1]; y++ ){
      for( int x = lower_limit.vec[0]; x<=upper_limit.vec[0]; x++ ){
	
	intd<3> grid_position;
	grid_position.vec[0] = x; grid_position.vec[1] = y; grid_position.vec[2] = z;
	
	NFFT_iterate_body<REAL,3>( alpha, beta, W, matrix_size_os, fixed_dims, number_of_batches, image, double_warp_size_power, 
				   half_W, one_over_W, matrix_size_os_real, sharedMemFirstSampleIdx, sample_position, grid_position );
      }
    }
  }
}

//
// This method is deliberately overloaded in 'd' (rather than templetized) to improve performance of the loop iteration
//

template<class REAL> __inline__ __device__ void
NFFT_iterate( REAL alpha, REAL beta, REAL W,
	      vectord<unsigned int,4> matrix_size_os, vectord<unsigned int,4> fixed_dims,
	      unsigned int number_of_batches, 
	      vectord<REAL,2> *image,
	      unsigned int double_warp_size_power, REAL half_W, REAL one_over_W, vectord<REAL,4> matrix_size_os_real, 
	      unsigned int sharedMemFirstSampleIdx,
	      vectord<REAL,4> sample_position, vectord<int,4> lower_limit, vectord<int,4> upper_limit )
{

  // Iterate through all grid cells influencing the corresponding sample
  for( int w = lower_limit.vec[3]; w<=upper_limit.vec[3]; w++ ){
    for( int z = lower_limit.vec[2]; z<=upper_limit.vec[2]; z++ ){
      for( int y = lower_limit.vec[1]; y<=upper_limit.vec[1]; y++ ){
	for( int x = lower_limit.vec[0]; x<=upper_limit.vec[0]; x++ ){
	  
	  intd<4> grid_position;
	  grid_position.vec[0] = x; grid_position.vec[1] = y; grid_position.vec[2] = z; grid_position.vec[3] = w;
	  
	  NFFT_iterate_body<REAL,4>( alpha, beta, W, matrix_size_os, fixed_dims, number_of_batches, image, double_warp_size_power, 
				     half_W, one_over_W, matrix_size_os_real, sharedMemFirstSampleIdx, sample_position, grid_position );
	}
      }
    }
  }
}

template<class REAL, unsigned int D> __inline__ __device__ void
NFFT_convolve( REAL alpha, REAL beta, REAL W,
	       vectord<unsigned int, D> matrix_size_os, vectord<unsigned int, D> matrix_size_wrap, vectord<unsigned int, D> fixed_dims,
	       unsigned int number_of_batches, 
	       vectord<REAL,D> *traj_positions, vectord<REAL,2> *image,
	       unsigned int double_warp_size_power, REAL half_W, REAL one_over_W, vectord<REAL,D> matrix_size_os_real, vectord<unsigned int, D> non_fixed_dims,
	       unsigned int globalThreadId, unsigned int sharedMemFirstSampleIdx )
{
  
  // Sample position to convolve onto
  // Computed in preprocessing, which included a wrap zone. Remove this wrapping.
  vectord<REAL,D> half_wrap_real; to_reald<REAL,unsigned int,D>(half_wrap_real, matrix_size_wrap>>1);
  vectord<REAL,D> sample_position = traj_positions[globalThreadId]-half_wrap_real;
  
  // Half the kernel width
  vectord<REAL,D> half_W_vec; to_vectord<REAL,D>( half_W_vec, half_W );
  
  // Limits of the subgrid to consider
  vectord<REAL,D> non_fixed_dims_real; to_reald<REAL,unsigned int,D>(non_fixed_dims_real,non_fixed_dims);
  vectord<int,D> lower_limit; to_intd<REAL,D>(lower_limit, ceil(sample_position-half_W_vec*non_fixed_dims_real));
  vectord<int,D> upper_limit; to_intd<REAL,D>(upper_limit, floor(sample_position+half_W_vec*non_fixed_dims_real));

  // Accumulate contributions from the grid
  NFFT_iterate<REAL>( alpha, beta, W, matrix_size_os, fixed_dims, number_of_batches, image, double_warp_size_power, 
			half_W, one_over_W, matrix_size_os_real, sharedMemFirstSampleIdx, sample_position, lower_limit, upper_limit );
}

//
// kernel main
//

template<class REAL, unsigned int D> __global__ void
NFFT_convolve_kernel( REAL alpha, REAL beta, REAL W,
		      vectord<unsigned int, D> matrix_size_os, vectord<unsigned int, D> matrix_size_wrap, vectord<unsigned int, D> fixed_dims,
		      unsigned int number_of_samples, unsigned int number_of_batches,
		      vectord<REAL,D> *traj_positions, vectord<REAL,2> *image, vectord<REAL,2> *samples,
		      unsigned int double_warp_size_power, REAL half_W, REAL one_over_W, vectord<REAL,D> matrix_size_os_real, vectord<unsigned int, D> non_fixed_dims )
{

  // Global thread number	
  const unsigned int globalThreadId = (blockIdx.x*blockDim.x+threadIdx.x);

  // Check if we are within bounds
  if( globalThreadId >= number_of_samples )
    return;
  
  // Number of reals to compute/output per thread
  const unsigned int num_reals = number_of_batches<<1;
  
  // All shared memory reals corresponding to domain 'threadIdx.x' are located in bank threadIdx.x%warp_size to limit bank conflicts
  const unsigned int scatterSharedMemStart = (threadIdx.x/warpSize)*warpSize;
  const unsigned int scatterSharedMemStartOffset = threadIdx.x&(warpSize-1); // a faster way of saying (threadIdx.x%warpSize) 
  const unsigned int sharedMemFirstSampleIdx = scatterSharedMemStart*num_reals + scatterSharedMemStartOffset;

  REAL *shared_mem = (REAL*) _shared_mem;
  REAL zero = get_zero<REAL>();

  // Initialize shared memory
  for( unsigned int i=0; i<num_reals; i++ )
    shared_mem[sharedMemFirstSampleIdx+warpSize*i] = zero;
  
  // Compute NFFT using arbitrary sample trajectories.
  NFFT_convolve<REAL,D>( alpha, beta, W, matrix_size_os, matrix_size_wrap, fixed_dims, number_of_batches, 
			 traj_positions, image, double_warp_size_power, half_W, one_over_W, 
			 matrix_size_os_real, non_fixed_dims, globalThreadId, sharedMemFirstSampleIdx );
  
  // Output k-space image to global memory
  NFFT_output<REAL>( number_of_samples, number_of_batches, samples, double_warp_size_power, globalThreadId, sharedMemFirstSampleIdx );
}