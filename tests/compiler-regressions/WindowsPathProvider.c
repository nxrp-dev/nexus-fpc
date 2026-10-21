// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
#ifdef SEARCH_LIBRARY
int nx_search_value(void) { return 1; }
#else
int nx_path_value(void) { return 42; }
#endif
