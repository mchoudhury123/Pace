#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dlfcn.h>

// Hook into the execve system call to intercept compiler invocations
int execve(const char *pathname, char *const argv[], char *const envp[]) {
    // Get the real execve function
    static int (*real_execve)(const char *pathname, char *const argv[], char *const envp[]) = NULL;
    if (!real_execve) {
        real_execve = dlsym(RTLD_NEXT, "execve");
    }
    
    // Check if this is a clang/clang++ invocation
    if (strstr(pathname, "clang") != NULL) {
        // Log to a file
        int log_fd = open("/tmp/compiler_hook.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
        if (log_fd >= 0) {
            dprintf(log_fd, "Intercepted compiler call: %s\n", pathname);
            
            // Make a copy of the argument array for modification
            char **new_argv = NULL;
            int argc = 0;
            while (argv[argc] != NULL) argc++;
            
            new_argv = malloc((argc + 2) * sizeof(char*));
            if (!new_argv) {
                dprintf(log_fd, "Failed to allocate memory for new argv\n");
                close(log_fd);
                return real_execve(pathname, argv, envp);
            }
            
            // Copy args, filtering out -G flag
            int new_idx = 0;
            for (int i = 0; i < argc; i++) {
                if (strcmp(argv[i], "-G") == 0) {
                    dprintf(log_fd, "Removing -G flag at position %d\n", i);
                } else {
                    new_argv[new_idx++] = argv[i];
                }
            }
            new_argv[new_idx] = NULL;
            
            // Log the modified command
            dprintf(log_fd, "Modified command:\n");
            for (int i = 0; i < new_idx; i++) {
                dprintf(log_fd, "  arg[%d]: %s\n", i, new_argv[i]);
            }
            close(log_fd);
            
            // Call the real execve with our modified arguments
            return real_execve(pathname, new_argv, envp);
        }
    }
    
    // For non-compiler calls, pass through unchanged
    return real_execve(pathname, argv, envp);
} 