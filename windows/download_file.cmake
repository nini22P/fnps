include(FetchContent)

if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

macro(download_file DOWNLOAD_URL EXPECTED_SHA256 TARGET_FILENAME)
    string(MAKE_C_IDENTIFIER "res_${TARGET_FILENAME}" INTERNAL_ID)
    
    message(STATUS "Downloading: ${TARGET_FILENAME}...")

    get_filename_component(FILE_EXT "${DOWNLOAD_URL}" LAST_EXT)
    set(IS_ZIP TRUE)
    if(FILE_EXT STREQUAL ".exe")
        set(IS_ZIP FALSE)
    endif()

    if(IS_ZIP)
        FetchContent_Declare(
            ${INTERNAL_ID}
            URL      "${DOWNLOAD_URL}"
            URL_HASH SHA256=${EXPECTED_SHA256}
            DOWNLOAD_NO_EXTRACT FALSE
            DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        )
    else()
        FetchContent_Declare(
            ${INTERNAL_ID}
            URL      "${DOWNLOAD_URL}"
            URL_HASH SHA256=${EXPECTED_SHA256}
            DOWNLOAD_NO_EXTRACT TRUE
        )
    endif()

    FetchContent_MakeAvailable(${INTERNAL_ID})

    FetchContent_GetProperties(${INTERNAL_ID} SOURCE_DIR)
    set(TMP_SRC_DIR "${${INTERNAL_ID}_SOURCE_DIR}")

    if(IS_ZIP)
        file(GLOB_RECURSE FOUND_PATH "${TMP_SRC_DIR}/${TARGET_FILENAME}")
        if(NOT FOUND_PATH)
            message(FATAL_ERROR "Not found file in archive: ${TARGET_FILENAME}")
        endif()
        list(GET FOUND_PATH 0 FINAL_PATH)
    else()
        get_filename_component(RAW_NAME "${DOWNLOAD_URL}" NAME)
        set(FINAL_PATH "${TMP_SRC_DIR}/${RAW_NAME}")
    endif()

    add_custom_command(
        TARGET ${BINARY_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${FINAL_PATH}"
        "$<TARGET_FILE_DIR:${BINARY_NAME}>/${TARGET_FILENAME}"
        VERBATIM
    )
endmacro()