/*
 * Copyright (c) 2021-2025 WangBin <wbsecg1 at gmail.com>
 */
#define _CRT_SECURE_NO_WARNINGS 1 // vc getenv
#if __has_include("shaderc/shaderc.h")
#include "shaderc/shaderc.h"
#undef SHADERC_EXPORT // avoid visibility is "default"
#define SHADERC_EXPORT
#include <cassert>
#include <string>
#include <iostream>
#include <vector>
#include <cstdlib>
#if defined(_WIN32)
# ifndef UNICODE
#   define UNICODE 1
# endif
# include <windows.h>
# ifdef WINAPI_FAMILY
#  include <winapifamily.h>
#  if !WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)
#    define SHADERC_WINRT 1
#  endif
# endif
# if (SHADERC_WINRT+0)
#   define dlopen(filename, flags) LoadPackagedLibrary(filename, 0)
# else
#   define dlopen(filename, flags) LoadLibrary(filename)
# endif
# define dlsym(handle, symbol) GetProcAddress((HMODULE)handle, symbol)
# define dlclose(handle) FreeLibrary((HMODULE)handle)
#else
# include <dlfcn.h>
#endif
using namespace std;

#define SHADERC_ARG0() (), (), ()
#define SHADERC_ARG1(P1) (P1), (P1 p1), (p1)
#define SHADERC_ARG2(P1, P2) (P1, P2), (P1 p1, P2 p2), (p1, p2)
#define SHADERC_ARG3(P1, P2, P3) (P1, P2, P3), (P1 p1, P2 p2, P3 p3), (p1, p2, p3)
#define SHADERC_ARG4(P1, P2, P3, P4) (P1, P2, P3, P4), (P1 p1, P2 p2, P3 p3, P4 p4), (p1, p2, p3, p4)
#define SHADERC_ARG5(P1, P2, P3, P4, P5) (P1, P2, P3, P4, P5), (P1 p1, P2 p2, P3 p3, P4 p4, P5 p5), (p1, p2, p3, p4, p5)
#define SHADERC_ARG6(P1, P2, P3, P4, P5, P6) (P1, P2, P3, P4, P5, P6), (P1 p1, P2 p2, P3 p3, P4 p4, P5 p5, P6 p6), (p1, p2, p3, p4, p5, p6)
#define SHADERC_ARG7(P1, P2, P3, P4, P5, P6, P7) (P1, P2, P3, P4, P5, P6, P7), (P1 p1, P2 p2, P3 p3, P4 p4, P5 p5, P6 p6, P7 p7), (p1, p2, p3, p4, p5, p6, p7)
#define SHADERC_ARG8(P1, P2, P3, P4, P5, P6, P7, P8) (P1, P2, P3, P4, P5, P6, P7, P8), (P1 p1, P2 p2, P3 p3, P4 p4, P5 p5, P6 p6, P7 p7, P8 p8), (p1, p2, p3, p4, p5, p6, p7, p8)

#define _SHADERC_API(R, NAME, ...) SHADERC_API_EXPAND(SHADERC_API_EXPAND_T_V(R, NAME, __VA_ARGS__))
#define SHADERC_API_EXPAND(EXPR) EXPR
#define SHADERC_API_EXPAND_T_V(R, F, ARG_T, ARG_T_V, ARG_V) \
    R F ARG_T_V { \
        static const auto fp = (decltype(&(F)))dlsym(load_once(), #F); \
        if (!fp) \
            return default_rv<R>(); \
        return fp ARG_V; \
    }

template<typename T> static T default_rv() {return {};}
template<> void default_rv<void>() {}

inline string to_string(const wchar_t* ws)
{
    string s(snprintf(nullptr, 0, "%ls", ws), 0);
    snprintf(&s[0], s.size() + 1, "%ls", ws);
    return s;
}

inline string to_string(const char* s) { return s;}

static auto libname(int version = -1)
{
    if (version < 0) {
        return
#if (_WIN32+0)
        basic_string<TCHAR>(TEXT("shaderc_shared.dll"))
#elif (__APPLE__+0)
        string("libshaderc_shared.dylib")
#else
        string("libshaderc_shared.so")
#endif
        ;
    }
#if (_WIN32+0)
    return L"shaderc_shared-" + to_wstring(version) + L".dll";
#elif (__APPLE__+0)
    return "libshaderc_shared." + to_string(version) + ".dylib";
#else
    return "libshaderc_shared.so." + to_string(version);
#endif
}

static auto load_shaderc()->decltype(dlopen(nullptr, RTLD_LAZY))
{
    const auto dso_env_a = std::getenv("SHADERC_LIB");
#if (_WIN32+0)
    wchar_t dso_env_w[128+1]; // enough. strlen is not const expr
    if (dso_env_a)
        mbstowcs(dso_env_w, dso_env_a, strlen(dso_env_a)+1);
    const auto dso_env = dso_env_a ? dso_env_w : nullptr;
#else
    const auto dso_env = dso_env_a;
#endif
    if (dso_env)
        return dlopen(dso_env, RTLD_NOW | RTLD_LOCAL);

    vector<int> vs{};//SHADERC_API_VERSION_MAJOR};
    for (int v = 1; v >= 1; --v) {
        //if (v != SHADERC_API_VERSION_MAJOR)
            vs.push_back(v);
    }
    vs.push_back(-1);
    invoke_result_t<decltype(libname), int> preName;
    for (auto v : vs) {
        const auto name = libname(v);
        if (preName == name)
            continue;
        preName = name;
        clog << "Try to load shaderc runtime: " << to_string(name.data()) << endl;
        if (auto dso = dlopen(name.data(), RTLD_NOW | RTLD_LOCAL))
            return dso;
    }
    clog << "Failed to load shaderc runtime" << endl;
    return nullptr;
}

static auto load_once()
{
    static auto dso = load_shaderc();
    return dso;
}

extern "C" {
_SHADERC_API(shaderc_compiler_t, shaderc_compiler_initialize, SHADERC_ARG0())
_SHADERC_API(void, shaderc_compiler_release, SHADERC_ARG1(shaderc_compiler_t))
_SHADERC_API(shaderc_compile_options_t, shaderc_compile_options_initialize, SHADERC_ARG0())
_SHADERC_API(shaderc_compile_options_t, shaderc_compile_options_clone, SHADERC_ARG1(const shaderc_compile_options_t))
_SHADERC_API(void, shaderc_compile_options_release, SHADERC_ARG1(shaderc_compile_options_t))
_SHADERC_API(void, shaderc_compile_options_add_macro_definition, SHADERC_ARG5(shaderc_compile_options_t, const char*, size_t, const char*, size_t))
_SHADERC_API(void, shaderc_compile_options_set_source_language, SHADERC_ARG2(shaderc_compile_options_t, shaderc_source_language))
_SHADERC_API(void, shaderc_compile_options_set_generate_debug_info, SHADERC_ARG1(shaderc_compile_options_t))
_SHADERC_API(void, shaderc_compile_options_set_optimization_level, SHADERC_ARG2(shaderc_compile_options_t, shaderc_optimization_level))
_SHADERC_API(void, shaderc_compile_options_set_forced_version_profile, SHADERC_ARG3(shaderc_compile_options_t, int, shaderc_profile))
_SHADERC_API(void, shaderc_compile_options_set_include_callbacks, SHADERC_ARG4(shaderc_compile_options_t, shaderc_include_resolve_fn, shaderc_include_result_release_fn, void*))
_SHADERC_API(void, shaderc_compile_options_set_suppress_warnings, SHADERC_ARG1(shaderc_compile_options_t))
_SHADERC_API(void, shaderc_compile_options_set_target_env, SHADERC_ARG3(shaderc_compile_options_t, shaderc_target_env, uint32_t))
_SHADERC_API(void, shaderc_compile_options_set_target_spirv, SHADERC_ARG2(shaderc_compile_options_t, shaderc_spirv_version))
_SHADERC_API(void, shaderc_compile_options_set_warnings_as_errors, SHADERC_ARG1(shaderc_compile_options_t))
_SHADERC_API(void, shaderc_compile_options_set_limit, SHADERC_ARG3(shaderc_compile_options_t, shaderc_limit, int))
_SHADERC_API(void, shaderc_compile_options_set_auto_bind_uniforms, SHADERC_ARG2(shaderc_compile_options_t, bool))
_SHADERC_API(void, shaderc_compile_options_set_auto_combined_image_sampler, SHADERC_ARG2(shaderc_compile_options_t, bool))
_SHADERC_API(void, shaderc_compile_options_set_binding_base, SHADERC_ARG3(shaderc_compile_options_t, shaderc_uniform_kind, uint32_t))
_SHADERC_API(void, shaderc_compile_options_set_binding_base_for_stage, SHADERC_ARG4(shaderc_compile_options_t, shaderc_shader_kind, shaderc_uniform_kind, uint32_t))
_SHADERC_API(void, shaderc_compile_options_set_preserve_bindings, SHADERC_ARG2(shaderc_compile_options_t, bool))
_SHADERC_API(void, shaderc_compile_options_set_auto_map_locations, SHADERC_ARG2(shaderc_compile_options_t, bool))
_SHADERC_API(shaderc_compilation_result_t, shaderc_compile_into_spv, SHADERC_ARG7(const shaderc_compiler_t, const char* , size_t, shaderc_shader_kind, const char* , const char* , const shaderc_compile_options_t))
_SHADERC_API(shaderc_compilation_result_t, shaderc_compile_into_spv_assembly, SHADERC_ARG7(const shaderc_compiler_t, const char* , size_t, shaderc_shader_kind, const char* , const char* , const shaderc_compile_options_t))
_SHADERC_API(shaderc_compilation_result_t, shaderc_compile_into_preprocessed_text, SHADERC_ARG7(const shaderc_compiler_t, const char* , size_t, shaderc_shader_kind, const char* , const char* , const shaderc_compile_options_t))
_SHADERC_API(shaderc_compilation_result_t, shaderc_assemble_into_spv, SHADERC_ARG4(const shaderc_compiler_t, const char* , size_t, const shaderc_compile_options_t))
_SHADERC_API(void, shaderc_result_release, SHADERC_ARG1(shaderc_compilation_result_t))
_SHADERC_API(size_t, shaderc_result_get_length, SHADERC_ARG1(const shaderc_compilation_result_t))
_SHADERC_API(size_t, shaderc_result_get_num_warnings, SHADERC_ARG1(const shaderc_compilation_result_t))
_SHADERC_API(size_t, shaderc_result_get_num_errors, SHADERC_ARG1(const shaderc_compilation_result_t))
_SHADERC_API(shaderc_compilation_status, shaderc_result_get_compilation_status, SHADERC_ARG1(const shaderc_compilation_result_t))
_SHADERC_API(const char*, shaderc_result_get_bytes, SHADERC_ARG1(const shaderc_compilation_result_t))
_SHADERC_API(const char*, shaderc_result_get_error_message, SHADERC_ARG1(const shaderc_compilation_result_t))
_SHADERC_API(void, shaderc_get_spv_version, SHADERC_ARG2(unsigned*, unsigned*))
}
#endif //__has_include("shaderc/shaderc.h")