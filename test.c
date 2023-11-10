#include <libXADMaster.h>

int main(int argc, const char **argv) {

    if (argc != 2) return PARAMETERS;

    char *path = argv[1];
    Archive *archive = ArchiveNew(path);
    
    return archive->error_num;

}
