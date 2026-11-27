#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char **argv) {
    if(argc!=2) return 2;
    FILE *f=fopen(argv[1],"rb");
    if(!f) { perror(argv[1]); return 1; }
    uint32_t t[256],c=UINT32_MAX;
    for(unsigned i=0;i<256;i++){
        uint32_t x=i;
        for(int j=0;j<8;j++) x=(x>>1)^((x&1)?UINT32_C(0x8E092638):0);
        t[i]=x;
    }
    static unsigned char buf[1024*1024];
    size_t n;
    while((n=fread(buf,1,sizeof buf,f))!=0)
        for(size_t i=0;i<n;i++) c=(c>>8)^t[(c^buf[i])&255];
    int bad=ferror(f);
    if(fclose(f)||bad) return 1;
    printf("%08x\n",(unsigned)(c^UINT32_MAX));
    return 0;
}
