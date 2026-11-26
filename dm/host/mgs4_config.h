#pragma once
#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "romfs_image.h"

// MGS4 graphics settings: regenerate only configuration files from the original image.
static char mgs4_overlay[PATH_MAX];
static void mgs4_cleanup(void) {
    if (!*mgs4_overlay) return;
    const char *files[] = {"mgs4.ini","mgs4.scalability.ini","mgs4.scalability_PC.ini","mgs4.scalability_NX.ini"};
    char p[PATH_MAX];
    for (int i=0;i<4;i++) { snprintf(p,sizeof p,"%s/config/%s",mgs4_overlay,files[i]); unlink(p); }
    snprintf(p,sizeof p,"%s/config",mgs4_overlay); rmdir(p); rmdir(mgs4_overlay);
}
// Accept only advertised values; never inject arbitrary INI text.
static const char *mgs4_choice(const char *name, const char *allowed) {
    const char *v=getenv(name);
    if (!v || !*v) return NULL;
    size_t n=strlen(v);
    for (const char *p=allowed; *p;) {
        size_t k=strcspn(p,"|");
        if (k==n && !memcmp(p,v,n)) return v;
        p+=k; if (*p) p++;
    }
    return NULL;
}
static const char *mgs4_override(int file, const char *section, const char *key, int custom) {
    const char *v;
    if (file == 3 && custom && !strncmp(section, "VFX_", 4) && !strcmp(key, "@3")) {
        const char *q = mgs4_choice("DM_MGS4_VFX_QUALITY", "0|1|2|3");
        static const char *levels[] = {"0.5", "0.7", "0.8", "1.0"};
        if (q) return levels[atoi(q)];
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"fullscreen")) {
        v=mgs4_choice("DM_MGS4_FULLSCREEN","true|false");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"fxaa")) {
        v=mgs4_choice("DM_MGS4_FXAA","true|false");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"fxaa_Switch_Docked")) {
        v=mgs4_choice("DM_MGS4_FXAA","true|false");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"fxaa_Switch_Handheld")) {
        v=mgs4_choice("DM_MGS4_FXAA","true|false");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"fxaaParam")) {
        v=mgs4_choice("DM_MGS4_FXAA_QUALITY","0|1|2");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"particleQuality")) {
        v=mgs4_choice("DM_MGS4_PARTICLES","0|1|2");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"particleQuality_Switch")) {
        v=mgs4_choice("DM_MGS4_PARTICLES","0|1|2");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"hardware_occlusion")) {
        v=mgs4_choice("DM_MGS4_OCCLUSION","true|false");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"backbufferCount")) {
        v=mgs4_choice("DM_MGS4_BACKBUFFERS","2|3");
        return v;
    }
    if (!file && !strcmp(section,"render") && !strcmp(key,"backbufferCount_Switch")) {
        v=mgs4_choice("DM_MGS4_BACKBUFFERS","2|3");
        return v;
    }
    if (!file && !strcmp(section,"texture") && !strcmp(key,"directory_Switch")) {
        v=mgs4_choice("DM_MGS4_TEXTURE_SOURCE","original|upscaled");
        return v ? (!strcmp(v,"original") ? "" : "NX_TXN_UP") : NULL;
    }
    if (!file && !strcmp(section,"texture") && !strcmp(key,"directoryTxnPak_Switch")) {
        v=mgs4_choice("DM_MGS4_TEXTURE_SOURCE","original|upscaled");
        return v ? (!strcmp(v,"original") ? "" : "NX_TXN_UP") : NULL;
    }
    if (!file && !strcmp(section,"texture") && !strcmp(key,"directoryTxnDataPak_Switch")) {
        v=mgs4_choice("DM_MGS4_TEXTURE_SOURCE","original|upscaled");
        return v ? (!strcmp(v,"original") ? "" : "NX_TXN_UP/paks") : NULL;
    }
    if (file==3 && custom && !strcmp(section,"Shadow@3") && !strcmp(key,"ShadowBufferSize")) {
        v=mgs4_choice("DM_MGS4_SHADOW_SIZE","512|1024|2048");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"Shadow@3") && !strcmp(key,"ShadowSampleCount")) {
        v=mgs4_choice("DM_MGS4_SHADOW_SAMPLES","4|7");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Default") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_DEFAULT","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_MissileSmoke") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_MISSILESMOKE","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_OctopusInkjet") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_OCTOPUSINKJET","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Fragment") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_FRAGMENT","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Blast") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_BLAST","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Weather") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_WEATHER","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Environment") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_ENVIRONMENT","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Rex") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_REX","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Bullet") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_BULLET","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_SandSmoke") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_SANDSMOKE","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_PE_Smoke") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_PE_SMOKE","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_RpgSmoke") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_RPGSMOKE","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_PE_Normal") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_PE_NORMAL","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_PE_Explosion") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_PE_EXPLOSION","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    if (file==3 && custom && !strcmp(section,"VFX_Mid_Explosion") && !strcmp(key,"@3")) {
        v=mgs4_choice("DM_MGS4_VFX_MID_EXPLOSION","0.1|0.2|0.3|0.5|0.6|0.65|0.7|0.75|0.8|0.9|1.0");
        return v;
    }
    return NULL;
}
static int mgs4_texture(FILE *out, const char *key, const char *original) {
    const char *fields[]={"MinLod","MaxLod","MipBias","MaxAniso"};
    const char *allowed[]={"0|1|2","0|16","0|1","1|2|4|8"};
    const char *groups[]={"TG_Default","TG_FixedModel","TG_Character","TG_FixedModel_Normal","TG_Character_Normal","TG_Effect","TG_UI","TG_NoMip","TG_NoBias"};
    int found=0; for (size_t j=0;j<sizeof groups/sizeof *groups;j++) if (!strcmp(key,groups[j])) found=1;
    if (!found) return 0;
    const char *values[4]={0}; int changed=0;
    for (int j=0;j<4;j++) {
        char env[128]; snprintf(env,sizeof env,"DM_MGS4_%s_%s",key,fields[j]);
        for (char *p=env;*p;p++) *p=(char)toupper((unsigned char)*p);
        values[j]=mgs4_choice(env,allowed[j]); if (values[j]) changed=1;
    }
    const char *q = mgs4_choice("DM_MGS4_TEXTURE_QUALITY", "0|1|2|3");
    if (q) {
        static const char *lod[] = {"2", "1", "0", "0"};
        static const char *bias[] = {"1", "0", "0", "0"};
        static const char *aniso[] = {"1", "4", "4", "8"};
        int level = atoi(q);
        if (!strcmp(key, "TG_UI") || !strcmp(key, "TG_NoMip") || !strcmp(key, "TG_NoBias")) return 0;
        values[0] = lod[level]; values[1] = "16";
        values[2] = bias[level]; values[3] = aniso[level];
        changed = 1;
    }
    if (!changed) return 0;
    char *copy=strdup(original); if (!copy) return 0;
    fprintf(out,"%s=",key); int emitted=0; char *save=NULL;
    for (char *t=strtok_r(copy,",\r\n",&save);t;t=strtok_r(NULL,",\r\n",&save)) {
        int j; for(j=0;j<4;j++) if (!strncmp(t,fields[j],strlen(fields[j])) && t[strlen(fields[j])]=='=') break;
        if (j<4 && values[j]) { fprintf(out,"%s%s=%s",emitted++?",":"",fields[j],values[j]); values[j]=NULL; }
        else fprintf(out,"%s%s",emitted++?",":"",t);
    }
    for(int j=0;j<4;j++) if(values[j]) fprintf(out,"%s%s=%s",emitted++?",":"",fields[j],values[j]);
    fputc('\n',out); free(copy); return 1;
}
static int mgs4_config(const char *romfs, const char *temp) {
    const char *r = getenv("DM_MGS4_RESOLUTION"), *f = getenv("DM_MGS4_FPS");
    const char *vs = getenv("DM_MGS4_VSYNC"), *dr = getenv("DM_MGS4_DYNAMIC_RESOLUTION");
    const char *w = "1920", *h = "1080";
    if (r && !strcmp(r, "1440")) { w = "2560"; h = "1440"; }
    else if (r && !strcmp(r, "2160")) { w = "3840"; h = "2160"; }
    f = f && (!strcmp(f,"30") || !strcmp(f,"60") || !strcmp(f,"120")) ? f : "60";
    const char *preset=mgs4_choice("DM_MGS4_PRESET","0|1|2|3|4");
    int custom=preset && !strcmp(preset,"4");
    if (!preset || custom) preset=custom ? "3" : "0";
    vs = vs && !strcmp(vs,"1") ? "1" : "0";
    dr = dr && !strcmp(dr,"1") ? "1" : "0";
    if (getenv("DM_ROMFS_OVERLAY")) {
        fprintf(stderr, "launcher: MGS4 external overlay supplied; automatic graphics configuration skipped\n");
        return 1;
    }
    char dir[PATH_MAX], path[PATH_MAX];
    if (snprintf(dir,sizeof dir,"%s/mgs4-graphics.XXXXXX",temp) >= sizeof dir || !mkdtemp(dir)) return 0;
    snprintf(mgs4_overlay,sizeof mgs4_overlay,"%s",dir);
    atexit(mgs4_cleanup);
    snprintf(path,sizeof path,"%s/config",dir);
    if (mkdir(path,0700)) return 0;
    romfs_img *im = romfs_image_open(romfs);
    if (!im) return 0;
    const img_ent *cfg = NULL;
    for (uint64_t j=0;j<im->e[0].b;j++) {
        const img_ent *e = &im->e[im->e[0].a+j];
        if (!e->type && e->nlen==6 && !memcmp(im->names+e->name,"config",6)) cfg=e;
    }
    const char *files[] = {"mgs4.ini","mgs4.scalability.ini","mgs4.scalability_PC.ini","mgs4.scalability_NX.ini"};
    int ok = cfg != NULL;
    for (int i=0;ok && i<4;i++) {
        const img_ent *e=NULL;
        for (uint64_t j=0;j<cfg->b;j++) {
            const img_ent *x=&im->e[cfg->a+j];
            if (x->type && x->nlen==strlen(files[i]) && !memcmp(im->names+x->name,files[i],x->nlen)) e=x;
        }
        if (!e || e->flags || e->b>1048576) { ok=0; break; }
        char *buf=malloc((size_t)e->b+1);
        if (!buf || !romfs_image_read(im->fd,buf,(size_t)e->b,(off_t)e->a)) { free(buf); ok=0; break; }
        buf[e->b]=0;
        snprintf(path,sizeof path,"%s/config/%s",dir,files[i]);
        FILE *out=fopen(path,"w");
        if (!out) { free(buf); ok=0; break; }
        int render=0, limiter=0; char section[80]="";
        for (char *line=buf;line && *line;) {
            char *next=strchr(line,'\n'); if(next) *next++=0;
            char *s=line; while(*s==' '||*s=='\t') s++;
            if (*s=='[') { section[0]=0; sscanf(s,"[%79[^]]]",section); render=!strncmp(s,"[render]",8); limiter=!strncmp(s,"[FPSLimiter]",12); }
            char *eq=strchr(s,'='); const char *value=NULL;
            if(eq) {
                char *end=eq; while(end>s && isspace((unsigned char)end[-1])) end--;
                size_t len=(size_t)(end-s);
#define KEY(k) (len==sizeof(k)-1 && !memcmp(s,k,sizeof(k)-1))
                if (!i && render) {
                    if(KEY("bufferSizeX")||KEY("bufferSizeX_Switch")) value=w;
                    if(KEY("bufferSizeY")||KEY("bufferSizeY_Switch")) value=h;
                    if(KEY("windowSizeX")||KEY("windowSizeX_Switch")||KEY("DockModeCropSizeX_Switch")) value=w;
                    if(KEY("windowSizeY")||KEY("windowSizeY_Switch")||KEY("DockModeCropSizeY_Switch")) value=h;
                    if(KEY("vsync")) value=*vs=='1'?"true":"false";
                    if(KEY("dynamicResolution")) value=*dr=='1'?"true":"false";
                }
                char key[128];
                if (len<sizeof key) {
                    memcpy(key,s,len); key[len]=0;
                    if (!i && !strcmp(section,"scalability") && KEY("scalabilityLevel_NX")) value=preset;
                    const char *override=mgs4_override(i,section,key,custom);
                    if (override) value=override;
                    if (i==3 && custom && !strcmp(section,"TextureGroup@3") && mgs4_texture(out,key,eq+1)) { line=next; continue; }
                }
                if(i && limiter && KEY("FPS_NX")) value=f;
#undef KEY
            }
            if(value) fprintf(out,"%.*s= %s\n",(int)(eq-line),line,value);
            else fprintf(out,"%s\n",line);
            line=next;
        }
        int bad=ferror(out); if(fclose(out)||bad) ok=0;
        free(buf);
    }
    romfs_image_close(im);
    if(!ok) return 0;
    setenv("DM_ROMFS_OVERLAY",dir,1);
    setenv("DM_MGS4_FPS",f,1); setenv("DM_MGS4_VSYNC",vs,1);
    setenv("DM_FPS_TARGET","0",1);
    setenv("DM_PRESENT_INTERVAL","display",1);
    setenv("DM_PRESENT_HZ","60",1);
    setenv("DM_SCREEN_MATCH","0",0);
    fprintf(stderr,"launcher: MGS4 graphics %sx%s, native swap chain, fps %s, vsync %s, dynamic %s, overlay %s\n",w,h,f,vs,dr,dir);
    return 1;
}

