
module ddparser.util;

import core.stdc.string;
public import core.stdc.stdint;
import core.stdc.ctype;
import std.ascii;
import std.string;
import std.stdio;
import std.json;
import ddparser.serialize;
import core.vararg;

enum INITIAL_SET_SIZE_INDEX =		2;

enum INITIAL_VEC_SHIFT =	3;
enum INITIAL_VEC_SIZE =	(1 << INITIAL_VEC_SHIFT);
enum INTEGRAL_VEC_SIZE =	3;
enum INTEGRAL_STACK_SIZE =	8;
/* enum TRICK_VEC_SIZE =		(INITIAL_VEC_SIZE - INTEGRAL_VEC_ELEMENTS); */

enum SET_MAX_SEQUENTIAL =	5;

bool IS_BIT_SET(T, V)(T _v, V _s) { return cast(bool)((_v)[(_s) / 8] & 1 << ((_s) % 8)); }
void SET_BIT(T, V)(ref T _v, V _s) { (_v)[(_s) / 8] |= (1 << ((_s) %8)); }

extern(C) __gshared int d_verbose_level = 0;
extern(C) __gshared int d_debug_level = 0;
extern(C) __gshared int test_level = 0;
extern(C) __gshared int d_rdebug_grammar_level = 0;

void trace(string file = __FILE__, int line = __LINE__, Args...)(Args args)
{
    /* write(file, ":", line, ": "); */
    /* writeln(args); */
}

bool isdigit_(T)(T c)
{
    return c.isDigit();
    /* return c >= cast(T)'0' && c <= cast(T)'9'; */
}

bool isxdigit_(T)(T c)
{
    return c.isHexDigit();
}

bool isspace_(T)(T c)
{
    return c.isWhite();
}

struct Vec(T)
{
    uint n;
    uint i;
    T *v;
    T e[INTEGRAL_VEC_SIZE];

    void clear()
    {
        n = 0;
        v = null;
    }

    void add(T _i)
    {
        if (!v) { 							
            v = e.ptr;
            e[n] = _i;
            n++;
            return;								
        } else if (v == e.ptr) { 					
            if ((n < INTEGRAL_VEC_SIZE)) { 				
                v[n++] = (_i); 					
                return;								
            }									
        } else if (n & (INITIAL_VEC_SIZE - 1)) { 			
            v[n++] = (_i); 						
            return;								
        }									
        vec_add_internal(_i); 						
    }

    void opOpAssign(string s)(T v) if (s == "~=")
    {
        add(v);
    }

    int opApply(int delegate(ref T) operations)
    {
        int res = 0;
        for(int i = 0; i < n; ++i)
        {
            res = operations(v[i]);
            if (res) break;
        }
        return res;
    }

    void vec_add_internal(T elem) {
        if (!n) {
            v = e.ptr;
        } else if (v == e.ptr) {
            v = cast(T*)MALLOC(INITIAL_VEC_SIZE * T.sizeof);
            memcpy(v, e.ptr, n * T.sizeof);
        } else {
            if ((n & (INITIAL_VEC_SIZE - 1)) == 0) {
                int l = n, nl = (1 + INITIAL_VEC_SHIFT);
                l = l >> INITIAL_VEC_SHIFT;
                while (!(l&1)) { l = l >> 1; nl++; }
                l = l >> 1;
                if (!n || !l) {
                    nl = 1 << nl;
                    v = cast(T*)REALLOC(v, nl * T.sizeof);
                }
            }
        }
        v[n] = elem;
        n++;
    }

    JSONValue customSerialize(Serializer s)
    {
        auto arr = v[0 .. n];
        return s.serializeValue(arr);
    }

    void customDeserialize(Serializer s, in JSONValue j)
    {
        auto arr = j.array;
        foreach(i; arr)
        {
            T t;
            s.deserializeValue(t, i);
            add(t);
        }
    }


    JSONValue toJSON()
    {
        static if (__traits(hasMember, T, "toJSON"))
        {

            JSONValue[] result;
            for (int i = 0; i < n; ++i)
            {
                if (v[i])
                    result ~= v[i].toJSON();
                else
                    result ~= JSONValue(null);
            }
            return JSONValue(result);
        }
        else
        {
            return JSONValue("ERROR!!!");
        }
    }
}

unittest
{
    Vec!int v;
}


alias AbstractVec = Vec!(void*);


void vec_add(T, U)(T _v, U _i)
{
    _v.add(_i);
}

struct Stack(_x) 
{
    _x *start;
    _x *end;
    _x *cur;
    _x initial[INTEGRAL_STACK_SIZE];

    void push(_x v)
    {
        if (cur == end )
            stack_push_internal(v);
        else
        {
            *cur = v;
            cur++;
        }
    }

    @property bool isEmpty()
    {
        return cur == start;
    }

    void stack_push_internal(_x elem)
    {
        auto n = cur - start;
        if (start == initial.ptr) {
            cur = cast(_x*)MALLOC(n * 2 * _x.sizeof);
            memcpy(cur, start, n * _x.sizeof);
        } else
            cur = cast(_x*)REALLOC(start, n * 2 * _x.sizeof);
        end = start = cur;
        cur += n;
        end += n * 2;
        *cur++ = elem;
    }

}

alias AbstractStack = Stack!(void*);


alias uint8 = ubyte;
alias uint16 = ushort;
alias uint32 = uint;
alias uint64 = ulong;


void vec_clear(T)(T vec)
{
    vec.clear();
}

alias vec_free = vec_clear;
bool is_stack_empty(T)(T _s)
{
    return _s.isEmpty;
}

void stack_push(T, U)(T _s, U _x)
{
    _s.push(_x);
}

auto stack_head(T)(T _s)
{
    return ((_s).cur[-1]);
}

auto stack_pop(T)(T _s)
{
    return (*--((_s).cur));
}

int stack_depth(T)(T _s)
{
    return cast(int)((_s).cur - (_s).start);
}

void stack_clear(T)(T _s)
{
    (_s).start = (_s).cur = (_s).end = (_s).initial.ptr;
    (_s).end += INTEGRAL_STACK_SIZE;
}

alias stack_free = stack_clear;

uint d_prime2[] = [
  1, 3, 7, 13, 31, 61, 127, 251, 509, 1021, 2039, 4093, 8191,
  16381, 32749, 65521, 131071, 262139, 524287, 1048573, 2097143,
  4194301, 8388593, 16777213, 33554393, 67108859, 134217689,
  268435399, 536870909
];

void* MALLOC(size_t s)
{
    import core.memory;
    return GC.calloc(s);
}

void* REALLOC(void* p, size_t s)
{
    import core.memory;
    return GC.realloc(p, s);
}

void FREE(void* p)
{

}


extern(C) int
set_find(void *av, void *t);
/*{
  AbstractVec *v = cast(AbstractVec*)av;
  int j, n = v.n;
  uint i;
  if (n) {
    uint h = (cast(uint)t);
    h = h % n;
    for (i = h, j = 0; 
	 i < v.n && j < SET_MAX_SEQUENTIAL; 
	 i = ((i + 1) % n), j++) 
    {
      if (!v.v[i]) {
	return 0;
      } else if (v.v[i] == t)
	return 1;
    }
  }
  return 0;
}*/
/*
int
set_add(void *av, void *t) {
  AbstractVec *v = cast(AbstractVec*)av, vv;
  int j, n = v.n;
  uint i;
  if (n) {
    uint h = (cast(uint)t);
    h = h % n;
    for (i = h, j = 0; 
	 i < v.n && j < SET_MAX_SEQUENTIAL; 
	 i = ((i + 1) % n), j++) 
    {
      if (!v.v[i]) {
	v.v[i] = t;
	return 1;
      } else if (v.v[i] == t)
	return 0;
    }
  }
  if (!n) {
    vv.v = null;
    v.i = INITIAL_SET_SIZE_INDEX;
  } else {
    vv.v = v.v;
    vv.n = v.n;
    v.i = v.i + 1;
  }
  v.n = d_prime2[v.i];
  v.v = cast(void**)MALLOC(v.n * (void *).sizeof);
  memset(v.v, 0, v.n * (void *).sizeof);
  if (vv.v) {
    set_union(av, &vv);
    FREE(vv.v);
  }
  return set_add(v, t);
}
*/
extern(C):
int set_add(void *av, void *t);
int set_union(void *v, void *vv);
char *escape_string(char *s);
char *escape_string_single_quote(char *s);
void *set_add_fn(void *v, void *t, hash_fns_t *fns);
void set_to_vec(void *av);

char *dup_code(const char *str, const char *end)
{
    if (0)
    {
    writeln("/+ g.r.final_code.code = dup_code(");
    writeln("q{");
    auto s = str[0 .. end - str].strip();
    //assert(s.startsWith("TRACE("));
    //assert(s.endsWith(")"));
    if (s.startsWith("TRACE("))
        s = s["TRACE(".length .. $ - 1];
    writeln(s);
    writeln("});");
    writeln("+/");
    }
    return dup_str(str, end);
}

import core.memory;

void* GC_MALLOC(size_t s)
{
    return GC.malloc(s);
}

void GC_FREE(void* p)
{

}

void* GC_CALLOC(size_t s, size_t n)
{
    return GC.calloc(s*n);
}

void* GC_REALLOC(void* p, size_t s)
{
    return GC.realloc(p, s);
}


alias hash_fn_t = uint function (void *, hash_fns_t*);
alias cmp_fn_t = int function (void *, void *, hash_fns_t*);
struct hash_fns_t {
  hash_fn_t	hash_fn;
  cmp_fn_t	cmp_fn;
  void		*data[2];
}

extern(C) void Trace(int line, char* str)
{
    if (0)
    {
    import std.array;
    char[] s = str[0 .. strlen(str)];
    s = s.replace("(D_PN(_ps, _offset).globals)", "g");
    s = s.replace(".", ".");
    s = s.replace("(*(D_PN(_children[0], _offset)))", "_c0");
    s = s.replace("(*(D_PN(_children[1], _offset)))", "_c1");
    s = s.replace("(D_PN(_children[0], _offset).user)", "_c0.user");
    s = s.replace("(D_PN(_children[1], _offset).user)", "_c1.user");
    s = s.replace("(D_PN(_ps, _offset).user)", "_ps.user");

    writeln("// TRACE ", line, "\n", s);
    }

}


extern(C) char *
d_dup_pathname_str(const(char)*s) {
    const(char)*e = s;
    if (!s)
        return dup_str("", null);
    if (*e == '"') {
        e++; while (*e && *e != '"') e++;
        return dup_str(s + 1, e);
    } else
        return dup_str(s, s+strlen(s));
}

extern(C) char *
dup_str(const char *s, const char *e) {
  int l = cast(int)(e ? e-s : strlen(s));
  char *ss = cast(char*)MALLOC(l+1);
  memcpy(ss, s, l);
  ss[l] = 0;
  return ss;
}

extern(C) uint
strhashl(const(char)*s, int l) {
  uint h = 0, g;
  int i = 0;

  for (;i < l;i++,s++) {
    h = (h << 4) + *s;
    if ((g = h & 0xf0000000) != 0)
      h = (h ^ (g >> 24)) ^ g;
  }
  return h;
}

extern(C) int
buf_read(const char *pathname, char **buf, int *len) {
    byte[] outbuf;
    foreach(chunk; File(pathname[0 .. strlen(pathname)].idup).byChunk(4096)) outbuf ~= chunk;
    *buf = cast(char*)outbuf.ptr;
    *len = cast(int)outbuf.length;
    return *len;
}

char *
sbuf_read(const char *pathname) {
  char *buf;
  int len;

  if (buf_read(pathname, &buf, &len) < 0)
    return null;
  return buf;
}

extern(C) void d_fail(const char * str, ...)
{
    writeln("error: ", str[0 .. strlen(str)]);
    assert(false);
}

extern(C) void d_warn(const char * str, ...)
{
    writeln("warning: ", str[0 .. strlen(str)]);
}

extern(C) void
vec_add_internal(void *v, void *elem) {
  AbstractVec *av = cast(AbstractVec*)v;
  av.vec_add_internal(elem);
}

void ESC(char c, ref char* ss)
{
    *ss = '\\';
    ss++;
    *ss = c;
    ss++;
}

char tohex1(ubyte _x)
{
    return ((((_x)&15) > 9) ? (((_x)&15) - 10 + 'A') : (((_x)&15) + '0'));
}

char tohex2(byte _x)
{
    return ((((_x)>>4) > 9) ? (((_x)>>4) - 10 + 'A') : (((_x)>>4) + '0'));
}

static char *
escape_string_internal(char *s, int single_quote) {
    char *ss = cast(char*)MALLOC((strlen(s) + 1) * 4), sss = ss;
    for (; *s; s++) {
        switch (*s) {
            case '\b': ESC('b', ss); break;
            case '\f': ESC('f', ss); break;
            case '\n': ESC('n', ss); break;
            case '\r': ESC('r', ss); break;
            case '\t': ESC('t', ss); break;
            case '\v': ESC('v', ss); break;
            case '\a': ESC('a', ss); break;
            case '\\': ESC('\\', ss); break;
            case '\"':
                       if (!single_quote) { ESC(*s, ss); break; }
                       *ss++ = *s;
                       break;
            case '\'':
                       if (single_quote) { ESC(*s, ss); break; }
                       *ss++ = *s;
                       break;
            default:
                       if (isprint(*s))
                           *ss++ = *s;
                       else {
                           *ss++ = '\\';
                           *ss++ = 'x';
                           *ss++ = tohex2(cast(ubyte)*s);
                           *ss++ = tohex1(cast(ubyte)*s);
                       }
                       break;
        }
    }
    *ss = 0;
    return sss;
}

extern(C) char *escape_string(char *s) { return escape_string_internal(s, 0); }
extern(C) char *escape_string_single_quote(char *s) { return escape_string_internal(s, 1); }

int
set_add(void *av, void *t) {
  AbstractVec *v = cast(AbstractVec*)av;
  AbstractVec vv;
  int j, n = v.n;
  uint i;
  if (n) {
    uint h = cast(uint)(cast(uintptr_t)t);
    h = h % n;
    for (i = h, j = 0; 
	 i < v.n && j < SET_MAX_SEQUENTIAL; 
	 i = ((i + 1) % n), j++) 
    {
      if (!v.v[i]) {
	v.v[i] = t;
	return 1;
      } else if (v.v[i] == t)
	return 0;
    }
  }
  if (!n) {
    vv.v = null;
    v.i = INITIAL_SET_SIZE_INDEX;
  } else {
    vv.v = v.v;
    vv.n = v.n;
    v.i = v.i + 1;
  }
  v.n = d_prime2[v.i];
  v.v = cast(void**)MALLOC(v.n * (void *).sizeof);
  memset(v.v, 0, v.n * (void *).sizeof);
  if (vv.v) {
    set_union(av, &vv);
    FREE(vv.v);
  }
  return set_add(v, t);
}

void *
set_add_fn(void *av, void *t, hash_fns_t *fns) {
  AbstractVec *v = cast(AbstractVec*)av;
  AbstractVec vv;
  uint32 tt = fns.hash_fn(t, fns);
  int j, n = v.n;
  uint i;
  if (n) {
    uint h = tt % n;
    for (i = h, j = 0; 
	 i < v.n && j < SET_MAX_SEQUENTIAL; 
	 i = ((i + 1) % n), j++) 
    {
      if (!v.v[i]) {
	v.v[i] = t;
	return t;
      } else {
	if (!fns.cmp_fn(v.v[i], t, fns))
	  return v.v[i];
      }
    }
  }
  if (!n) {
    vv.v = null;
    v.i = INITIAL_SET_SIZE_INDEX;
  } else {
    vv.v = v.v;
    vv.n = v.n;
    v.i = v.i + 1;
  }
  v.n = d_prime2[v.i];
  v.v = cast(void**)MALLOC(v.n * (void *).sizeof);
  memset(v.v, 0, v.n * (void *).sizeof);
  if (vv.v) {
    set_union_fn(av, &vv, fns);
    FREE(vv.v);
  }
  return set_add_fn(v, t, fns);
}

int
set_union(void *av, void *avv) {
  AbstractVec *vv = cast(AbstractVec*)avv;
  uint i, changed = 0;
  
  for (i = 0; i < vv.n; i++)
    if (vv.v[i])
      changed = set_add(av, vv.v[i]) || changed;
  return changed;
}

void
set_union_fn(void *av, void *avv, hash_fns_t *fns) {
  AbstractVec *vv = cast(AbstractVec*)avv;
  uint i;
  
  for (i = 0; i < vv.n; i++)
    if (vv.v[i])
      set_add_fn(av, vv.v[i], fns);
}

void
set_to_vec(void *av) {
  AbstractVec *v = cast(AbstractVec*)av;
  AbstractVec vv;
  uint i;

  vv.n = v.n;
  vv.v = v.v;
  if (v.v == v.e.ptr) {
    memcpy(vv.e.ptr, v.e.ptr, (v.e).sizeof);
    vv.v = vv.e.ptr;   
  }
  v.n = 0;
  v.v = null;
  for (i = 0; i < vv.n; i++)
    if (vv.v[i])
      vec_add_internal(v, vv.v[i]);
  FREE(vv.v);
}

int
set_find(void *av, void *t) {
  AbstractVec *v = cast(AbstractVec*)av;
  int j, n = v.n;
  uint i;
  if (n) {
    uint h = cast(uint)(cast(uintptr_t)t);
    h = h % n;
    for (i = h, j = 0; 
	 i < v.n && j < SET_MAX_SEQUENTIAL; 
	 i = ((i + 1) % n), j++) 
    {
      if (!v.v[i]) {
	return 0;
      } else if (v.v[i] == t)
	return 1;
    }
  }
  return 0;
}

void d_free(void *x) { FREE(x); }

import std.format;
import std.algorithm;
import std.array;

void delegate(string s) logFunc;

void log(Args...)(Args args)
{
    writeln(args);
}

void logf(Args...)(Args args)
{
    auto writer = appender!string();
    formattedWrite(writer, args);
    if (logFunc) logFunc(writer.data);
    else write(writer.data);
}

