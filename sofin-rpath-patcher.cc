/*
    Authors: Michał Lipski
             Daniel (dmilith) Dettlaff
    © 2013 - VerKnowSys
*/


#include <stdio.h>
#include <iostream>
#include <vector>
#include <iterator>
#include <algorithm>
#include <string.h>
#include <fstream>
#include <sstream>
#include <sys/stat.h>
#include <sys/fcntl.h>
#include <errno.h>
#include <regex.h>
#if defined(__FreeBSD__) || defined(__linux__)
    #include <cstdlib>
    #include <sys/wait.h>
#endif
#include <sys/user.h>

#define APP_VERSION "0.3.7"
#define COPYRIGHT "Copyright © 2o13 VerKnowSys.com - All Rights Reserved."
#define BUILD_USER_HOME "/7a231cbcbac22d3ef975e7b554d7ddf09b97782b/"
#define BUILD_USER_NAME "build-user"
#define BUILD_USER_HOME_DIR BUILD_USER_HOME BUILD_USER_NAME
#define REPLACED_SIZE_ERROR 100
#define PATCHED_FILE_SIZE_ERROR 101
#define NOT_ENOUGH_ARGS_ERROR 102

#define N_ELEMENTS(arr) (sizeof(arr) / sizeof((arr)[0]))

using namespace std;


bool binary_magic_match(string &filename) {
    bool matched = false;
    const unsigned char magic[][4] = {
    #ifdef __APPLE__
        { 0xCE, 0xFA, 0xED, 0xFE }, // 32-bit
        { 0xCA, 0xFE, 0xBA, 0xBE }, // Universal
        { 0xCF, 0xFA, 0xED, 0xFE }, // 64-bit
    #else
        { 0x7F, 0x45, 0x4C, 0x46 }, // ELF
    #endif
    };

    char buf[4];
    ifstream file(filename.c_str());
    file.read(buf, 4);

    for (int i = 0; i < N_ELEMENTS(magic); ++i) {
        matched = false;
        for (int j = 0; j < sizeof(buf); ++j) {
            if (buf[j] == magic[i][j])
                matched = true;
            else {
                matched = false;
                break;
            }
        }
        if (matched)
            break;
    }

    file.close();

    return matched;
}


bool ext_match(string &filename, vector<string> &ext) {
    regex_t regex;
    int ret;
    bool matched = false;

    for (vector<string>::iterator it = ext.begin(); it != ext.end(); ++it) {
        string pattern = *it;
        cout << " * Matching extension: " << pattern << endl;

        if (regcomp(&regex, pattern.c_str(), 0)) {
            cerr << "Could not compile regex" << endl;
            return false;
        }

        ret = regexec(&regex, filename.c_str(), 0, NULL, 0);
        regfree(&regex);

        if (!ret) {
            cout << " * Matched" << endl;
            matched = true;
            break;
        }
    }

    return matched;
}


bool binary_ext_match(string &filename) {
    vector<string> ext;
    ext.push_back("\\.a$");
    ext.push_back("\\.so[0-9\\.]*$");
#if __APPLE__
    ext.push_back("\\.dylib$");
#endif

    return ext_match(filename, ext);
}


bool is_binary(string &filename) {

    if (binary_ext_match(filename))
        return true;

    if (binary_magic_match(filename))
        return true;

    return false;
}


const string replace_prefix_in_path(string &path, string &home, string &bundle) {
    regex_t regex;
    regmatch_t match[1];
    int ret;

    if (regcomp(&regex, BUILD_USER_HOME_DIR, 0)) {
        cerr << "Could not compile regex" << endl;
        return path;
    }

    ret = regexec(&regex, path.c_str(), 1, match, 0);
    regfree(&regex);

    if (!ret)
        /* Replace home dir */
        path.replace(match[0].rm_so, match[0].rm_eo - match[0].rm_so, home);

    if (regcomp(&regex, "/Apps/[A-Za-z0-9\\.\\-]*", 0)) {
        cerr << "Could not compile regex" << endl;
        return path;
    }

    ret = regexec(&regex, path.c_str(), 1, match, 0);
    regfree(&regex);

    if (!ret)
        /* Replace bundle name */
        path.replace(match[0].rm_so, match[0].rm_eo - match[0].rm_so, "/Apps/" + bundle);

    return path;
}


void replace_original_file(string &patched, string &original) {
    struct stat st;
    cout << " * Renaming `" << patched << "` to `" << original << "`" << endl;
    stat(original.c_str(), &st);
    rename(patched.c_str(), original.c_str());
    chmod(original.c_str(), st.st_mode);
}


int main(int argc, char const *argv[]) {

    int error = 0;
    ifstream ifs;
    ofstream ofs;
    size_t isize, osize;
    char c;
    vector<char> buf;
    bool binary;

    if (strcmp(getenv("USER"), BUILD_USER_NAME) == 0)
        return 0;

    cout << " * Sofin RPath Patcher " << APP_VERSION << " - " << COPYRIGHT << endl;

    if (argc < 3) {
        cerr << "Not enough arguments!" << endl;
        cerr << "   Usage: sofin-rpp Destination-bundle-name /absolute/path/to/any-file" << endl;
        exit(NOT_ENOUGH_ARGS_ERROR);
    }

    string bundle = argv[1];
    string original_filename = argv[2];
    string patched_filename = original_filename + ".patched";

    binary = is_binary(original_filename);

    cout << " * Patching file: " << original_filename << endl;
    cout << " * Binary: " << (binary ? "yes" : "no") << endl;

    // if (!binary) {
    //     cout << " * Probably a text file. Exiting..." << endl << endl;
    //     exit(0);
    // }


    ifs.open(original_filename.c_str(), ios::binary);
    istream_iterator<char> begin(ifs), end;
    vector<size_t> positions;

    string home = getenv("HOME");
    string prefix = home + "/Apps/" + bundle;
    cout << " * Prefix: " << prefix << endl;

    string pattern = string(BUILD_USER_HOME_DIR);
    cout << " * Searching for pattern: " << pattern << endl;

    while (ifs.good()) {
        begin = search(begin, end, pattern.begin(), pattern.end());

        if (begin != end) {
            size_t global = (size_t)ifs.tellg() - pattern.length();
            positions.push_back(global);
        }
    }
    ifs.clear();
    ifs.seekg(0, ios::beg);

    if (positions.size() == 0) {
        cout << " * Patterns were not found. Exiting..." << endl;
        goto DONE;
    }

    ofs.open(patched_filename.c_str(), fstream::binary);
    cout << " * Writing to file: " << patched_filename << endl;

    for (std::vector<size_t>::iterator it = positions.begin(); it != positions.end(); ++it) {

        bool last = (positions.end() - it == 1);
        size_t next_pos = *(it + 1);

        /* Write data until the occurrence of the search string */
        while (ifs.tellg() < *it) {
            ifs.get(c);
            ofs.put(c);
        }

        while (ifs.good()) {
            ifs.get(c);

            /* Break on non-printable and whitespace */
            if (c >= 0 && c < 33) {
                ifs.seekg(-1, ios::cur);
                break;
            }

            if (not last && (size_t)ifs.tellg() == next_pos) {
                ifs.seekg(-1, ios::cur);
                break;
            }

            buf.push_back(c);
        }

        /* Replace string */
        if (not buf.empty()) {
            string str(buf.begin(), buf.end());
            size_t str_len = str.length();

            string replaced = replace_prefix_in_path(str, home, bundle);

            if (replaced.length() > str_len) {
                cout << " * Fatal: Replaced string is greater than original ("
                     << replaced.length() << " vs " << str_len << ")" << endl;
                error = REPLACED_SIZE_ERROR;
                goto DONE;
            }

            if (binary) {
                /* HACK: prepend path with /././././. */
                int fill = replaced.length();
                for ( ; fill + 1 < str_len; fill += 2)
                    ofs << "/.";
                if (fill < str_len)
                    ofs << '/';
            }
            /* Write replaced string */
            ofs << replaced;
        }
        /* Clear buffer */
        buf.clear();
    }
    /* Write everything else */
    while (ifs.get(c)) {
        if (ifs.good())
            ofs.put(c);
    }

    ifs.clear();
    ifs.seekg(0, ifs.end);
    isize = ifs.tellg();

    ofs.clear();
    ofs.seekp(0, ofs.end);
    osize = ofs.tellp();

    cout << " * Input: " << isize << " bytes." << endl;
    cout << " * Output: " << osize << " bytes." << endl;

    if (binary && isize != osize) {
        cout << " * Failure: Patched file size differs from original file." << endl;
        error = PATCHED_FILE_SIZE_ERROR;
        goto DONE;
    }

DONE:
    ifs.close();
    ofs.close();
    positions.clear();
    buf.clear();

    if (!error) {
        replace_original_file(patched_filename, original_filename);
        cout << " * Success" << endl << endl;
        exit(0);
    } else {
        // unlink(patched_filename.c_str());
        cout << endl;
        exit(error);
    }
}
