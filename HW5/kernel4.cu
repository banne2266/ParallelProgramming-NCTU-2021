#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#define BLOCK_SIZE 8
#define GROUP_SIZE 2

__global__ void mandelKernel(int resX, int resY, float stepX, float stepY, int *GPUresult, float lowerX, float lowerY, int maxIterations, size_t pitch) {
    // To avoid error caused by the floating number, use the following pseudo code
    //
    // float x = lowerX + thisX * stepX;
    // float y = lowerY + thisY * stepY;
    int thisX = (blockIdx.x * blockDim.x + threadIdx.x) * GROUP_SIZE;
    int thisY = (blockIdx.y * blockDim.y + threadIdx.y);
    float x;
    float y;
    float z_re, z_im;

    for(int i = 0; i < GROUP_SIZE; i++){
        if(thisX + i >= resX || thisY >= resY)
            continue;
        x = lowerX + (thisX+i) * stepX;
        y = lowerY + thisY * stepY;
        z_re = x, z_im = y;
        int t = 0;
        for (t = 0; t < maxIterations; ++t){
            if (z_re * z_re + z_im * z_im > 4.f)
                break;
            float new_re = z_re * z_re - z_im * z_im;
            float new_im = 2.f * z_re * z_im;
            z_re = x + new_re;
            z_im = y + new_im;
        }
        *((int*)((char*)GPUresult + thisY * pitch) + thisX + i) = t;
    }    
}

// Host front-end function that allocates the memory and launches the GPU kernel
void hostFE (float upperX, float upperY, float lowerX, float lowerY, int* img, int resX, int resY, int maxIterations)
{
    float stepX = (upperX - lowerX) / resX;
    float stepY = (upperY - lowerY) / resY;
    size_t pitch = 0;

    int size = resX * resY;
    int *result_h;
    int *result_d;
    cudaMallocPitch((void **)&result_d, &pitch, resX * sizeof(int), resY);

    dim3 blockSize(BLOCK_SIZE, BLOCK_SIZE);
    dim3 numBlock((resX + GROUP_SIZE * BLOCK_SIZE - 1) / BLOCK_SIZE / GROUP_SIZE, (resY +  GROUP_SIZE * BLOCK_SIZE - 1) / BLOCK_SIZE);

    mandelKernel<<<numBlock, blockSize>>>(resX, resY, stepX, stepY, result_d, lowerX, lowerY, maxIterations, pitch);

    cudaDeviceSynchronize();
    cudaMemcpy2D(img, resX * sizeof(int), result_d, pitch, resX * sizeof(int), resY, cudaMemcpyDeviceToHost);

    cudaFree(result_d);
}
