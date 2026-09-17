#pragma once

namespace BenchmarkConfig
{
    constexpr const char* CaseId = AYAGAMI_BENCHMARK_CASE_ID;
    constexpr const char* CoreProvider = AYAGAMI_BENCHMARK_CORE_PROVIDER;
    constexpr const char* WorkloadId = AYAGAMI_BENCHMARK_WORKLOAD_ID;
    constexpr const char* ModelName = AYAGAMI_BENCHMARK_MODEL_NAME;
    constexpr const char* ModelHash = AYAGAMI_BENCHMARK_MODEL_HASH;
    constexpr int ModelCount = AYAGAMI_BENCHMARK_MODEL_COUNT;
    constexpr int Columns = AYAGAMI_BENCHMARK_COLUMNS;
    constexpr int Rows = AYAGAMI_BENCHMARK_ROWS;
    constexpr int Width = AYAGAMI_BENCHMARK_WIDTH;
    constexpr int Height = AYAGAMI_BENCHMARK_HEIGHT;
    constexpr double WarmupSeconds = AYAGAMI_BENCHMARK_WARMUP_SECONDS;
    constexpr double SampleSeconds = AYAGAMI_BENCHMARK_SAMPLE_SECONDS;
}
