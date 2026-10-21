// =====================================================
//  GPU Diagnostic Tool (C++ / CUDA)
//
//  The diagnostic engine behind the dashboard in this repo.
//  NVML reads real hardware telemetry (temperature, fan speed)
//  straight from the GPU driver; CUDA kernels run the memory and
//  compute checks on the device's own cores.
//
//  How to run:  ./diag
//  To test faults: set injectFault to true below,
//  then compile and run again.
//
//  Mirrored into gpu_diagnostics_cpp.ipynb (step 2) so Colab can
//  write and compile it against a real GPU with no local setup.
// =====================================================

#include <iostream>
#include <cuda_runtime.h>
#include <nvml.h>

using namespace std;


// =====================================================
//  PART 1: Settings shared by the whole program
// =====================================================

bool injectFault = false;      // change to true to test faults
nvmlDevice_t gpu;              // ID card for the GPU being tested

int testsRun = 0;
int testsFailed = 0;


// =====================================================
//  PART 2: Health checks (ask the GPU about itself)
// =====================================================

bool testTemperature() {
    unsigned int temp = 0;
    nvmlReturn_t result = nvmlDeviceGetTemperature(gpu, NVML_TEMPERATURE_GPU, &temp);

    // If the reading itself failed, temp would stay 0 and wrongly PASS.
    // So: no reading means no pass.
    if (result != NVML_SUCCESS) {
        cout << "   ERROR: could not read temperature" << endl;
        return false;
    }

    unsigned int limit = 85;
    if (injectFault == true) {
        limit = 10;            // fault: no GPU is this cold
    }

    cout << "   temperature: " << temp << " C (limit " << limit << " C)" << endl;

    if (temp >= limit) {
        cout << "   ERROR: GPU is too hot" << endl;
        return false;
    }
    return true;
}

bool testFan() {
    unsigned int speed = 0;
    nvmlDeviceGetFanSpeed(gpu, &speed);   // stays 0 if the GPU has no fan sensor

    if (injectFault == true) {
        speed = 150;           // fault: impossible speed
    }

    cout << "   fan speed: " << speed << "%" << endl;

    if (speed > 100) {
        cout << "   ERROR: fan speed is impossible" << endl;
        return false;
    }
    return true;
}


// =====================================================
//  PART 3: GPU kernels (small functions that run ON the GPU)
//  Thousands of copies run at once, one per number.
// =====================================================

__global__ void fillMemory(unsigned int* data, int n, unsigned int pattern) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;   // which number am I?
    if (i < n) {
        data[i] = pattern;
    }
}

__global__ void addNumbers(float* a, float* b, float* result, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;   // which number am I?
    if (i < n) {
        result[i] = a[i] + b[i];
    }
}


// =====================================================
//  PART 4: GPU tests (make the GPU do work, check the answers)
// =====================================================

// Write patterns into GPU memory, read them back, count mistakes
bool testMemory() {
    int n = 1000000;
    unsigned int* data;
    cudaMallocManaged(&data, n * sizeof(unsigned int));   // memory both CPU and GPU can use

    unsigned int patterns[4] = {0x00000000, 0xFFFFFFFF, 0xAAAAAAAA, 0x55555555};
    int mistakes = 0;

    for (int p = 0; p < 4; p++) {
        fillMemory<<<(n + 255) / 256, 256>>>(data, n, patterns[p]);
        cudaDeviceSynchronize();          // wait for the GPU to finish

        if (injectFault == true) {
            data[1000] = 12345;           // fault: corrupt one value
        }

        for (int i = 0; i < n; i++) {
            if (data[i] != patterns[p]) {
                mistakes++;
            }
        }
    }

    cudaFree(data);
    cout << "   memory: " << mistakes << " wrong values" << endl;

    if (mistakes > 0) {
        cout << "   ERROR: GPU memory is not storing values correctly" << endl;
        return false;
    }
    return true;
}

// Add numbers on the GPU, then check every answer on the CPU
bool testCompute() {
    int n = 1000000;
    float *a, *b, *result;
    cudaMallocManaged(&a, n * sizeof(float));
    cudaMallocManaged(&b, n * sizeof(float));
    cudaMallocManaged(&result, n * sizeof(float));

    for (int i = 0; i < n; i++) {
        a[i] = i * 1.0f;
        b[i] = i * 2.0f;
    }

    addNumbers<<<(n + 255) / 256, 256>>>(a, b, result, n);
    cudaDeviceSynchronize();              // wait for the GPU to finish

    if (injectFault == true) {
        result[500] = -1.0f;              // fault: one wrong answer
    }

    int wrong = 0;
    for (int i = 0; i < n; i++) {
        if (result[i] != a[i] + b[i]) {
            wrong++;
        }
    }

    cudaFree(a);
    cudaFree(b);
    cudaFree(result);
    cout << "   compute: " << wrong << " wrong answers" << endl;

    if (wrong > 0) {
        cout << "   ERROR: GPU gave wrong answers" << endl;
        return false;
    }
    return true;
}


// =====================================================
//  PART 5: Print PASS or FAIL for one test
// =====================================================

void report(const char* name, bool passed) {
    testsRun++;
    if (passed == true) {
        cout << "   [" << name << "] PASS" << endl;
    } else {
        cout << "   [" << name << "] FAIL" << endl;
        testsFailed++;
    }
}


// =====================================================
//  PART 6: main - count the GPUs, test each one
// =====================================================

int main() {

    nvmlInit();                                  // start NVIDIA's library

    unsigned int count = 0;
    nvmlDeviceGetCount(&count);                  // 1. count the GPUs
    cout << "Found " << count << " GPU(s)" << endl << endl;

    for (unsigned int i = 0; i < count; i++) {   // 2. visit each one
        nvmlDeviceGetHandleByIndex(i, &gpu);     // 3. get its ID card
        cudaSetDevice(i);                        //    and point CUDA at it too
        cout << "Checking GPU " << i << endl;

        report("temp", testTemperature());       // 4. run the checks
        report("fan", testFan());
        report("memory", testMemory());
        report("compute", testCompute());
        cout << endl;
    }

    cout << "Summary: " << testsRun << " run, " << testsFailed << " failed" << endl;

    nvmlShutdown();
    return 0;
}
