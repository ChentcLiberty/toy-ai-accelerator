#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

void matmul_ref(
    int8_t* A,
    int8_t* B,
    int32_t* C,
    int M,
    int N,
    int K
) {
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            int32_t sum = 0;
            for (int k = 0; k < K; k++) {
                int8_t a = A[i*K + k];
                int8_t b = B[k*N + j];
                sum += (int32_t)a * (int32_t)b;
            }
            C[i*N + j] = sum;
        }
    }
}

int main() {
    int M = 2;
    int N = 2;
    int K = 2;

    int8_t A[4] = {
        1, 2,
        3, 4
    };

    int8_t B[4] = {
        5, 6,
        7, 8
    };

    int32_t C[4] = {0};

    matmul_ref(A, B, C, M, N, K);

    printf("Result C:\n");
    for (int i = 0; i < M; i++) {
        for (int j = 0; j < N; j++) {
            printf("%d ", C[i*N + j]);
        }
        printf("\n");
    }

    return 0;
}

