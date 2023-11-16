#include <libXADMaster.h>

int main(int argc, const char **argv) {

    if (argc != 2) return PARAMETERS;

    const char *path = argv[1];
    Archive *archive = ArchiveNew(path);

    int ret = archive->error_num;
    ArchiveDestroy(archive);
    
    return ret;

}
