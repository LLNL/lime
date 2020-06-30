
#ifndef _PORT_DMA_H
#define _PORT_DMA_H

#include <iomanip> // hex, setw
#include "systemc.h"

// memory mapped interface
#if 1
#define MD 64 // data width
#define MA 32 // address width
#define MI 2  // id width
#define MU 8  // user width
#else
#define MD 32 // data width
#define MA 32 // address width
#define MI 2  // id width
#define MU 8  // user width
#endif

#if defined(__SYNTHESIS__)
#define TAG_T  TAG::ui_t
#define DMAC_T DMAC::ui_t
#define DMAS_T DMAS::ui_t
#else
#define TAG_T  TAG
#define DMAC_T DMAC
#define DMAS_T DMAS
#endif

#define TAG_CONCAT \
	(req,did)

class TAG { // DMA tag
public:
	typedef sc_uint<(1+CI)> ui_t;

	sc_uint<CI> did; // destination id
	sc_uint<1>  req; // request status

	TAG(ui_t ui = 0)
	{
		TAG_CONCAT = ui;
	}

	TAG& operator=(ui_t ui)
	{
		TAG_CONCAT = ui;
		return *this;
	}

	operator ui_t() const
	{
		return TAG_CONCAT;
	}

	bool operator==(const TAG& ob)
	{
		return
			this->did == ob.did &&
			this->req  == ob.req;
	}
};

inline std::ostream& operator<<(std::ostream& os, const TAG& ob)
{
	return os << hex << ob.req << ':' << ob.did;
}

inline void sc_trace(sc_trace_file* tf, const TAG& ob, const std::string& nm)
{
	sc_trace(tf, ob.did, nm+".did");
	sc_trace(tf, ob.req, nm+".req");
}

#define DMAC_CONCAT \
	(tag.req,tag.did,addr,last,size)

class DMAC { // DMA command
public:
	typedef sc_biguint<((1+CI)+MA+1+24)> ui_t;

	sc_uint<24>    size; // size in bytes to transfer
	sc_uint<1>     last; // last block of packet
	sc_biguint<MA> addr; // address to start transfer
	TAG            tag ; // tag

	DMAC(ui_t ui = 0)
	{
		DMAC_CONCAT = ui;
	}

	DMAC& operator=(ui_t ui)
	{
		DMAC_CONCAT = ui;
		return *this;
	}

	operator ui_t() const
	{
		return DMAC_CONCAT;
	}

	bool operator==(const DMAC& ob)
	{
		return
			this->size == ob.size &&
			this->last == ob.last &&
			this->addr == ob.addr &&
			this->tag  == ob.tag;
	}
};

inline std::ostream& operator<<(std::ostream& os, const DMAC& ob)
{
	return os << hex << ob.tag << ':'  << ob.addr << ':' << ob.last << ':' << ob.size;
}

inline void sc_trace(sc_trace_file* tf, const DMAC& ob, const std::string& nm)
{
	sc_trace(tf, ob.size, nm+".size");
	sc_trace(tf, ob.last, nm+".last");
	sc_trace(tf, ob.addr, nm+".addr");
	sc_trace(tf, ob.tag,  nm+".tag");
}

#define DMAS_CONCAT \
	(okay,slverr,decerr,interr,tag.req,tag.did)

class DMAS { // DMA status
public:
	typedef sc_biguint<(1+1+1+1+(1+CI))> ui_t;

	TAG        tag   ; // tag
	sc_uint<1> interr; // internal error
	sc_uint<1> decerr; // decode error
	sc_uint<1> slverr; // slave error
	sc_uint<1> okay  ; // transfer completed

	DMAS(ui_t ui = 0)
	{
		DMAS_CONCAT = ui;
	}

	DMAS& operator=(ui_t ui)
	{
		DMAS_CONCAT = ui;
		return *this;
	}

	operator ui_t() const
	{
		return DMAS_CONCAT;
	}

	bool operator==(const DMAS& ob)
	{
		return
			this->tag    == ob.tag &&
			this->interr == ob.interr &&
			this->decerr == ob.decerr &&
			this->slverr == ob.slverr &&
			this->okay   == ob.okay;
	}
};

inline std::ostream& operator<<(std::ostream& os, const DMAS& ob)
{
	return os << hex << ob.okay << ':'  << ob.slverr << ':'  << ob.decerr << ':' << ob.interr << ':' << ob.tag;
}

inline void sc_trace(sc_trace_file* tf, const DMAS& ob, const std::string& nm)
{
	sc_trace(tf, ob.tag,    nm+".tag");
	sc_trace(tf, ob.interr, nm+".interr");
	sc_trace(tf, ob.decerr, nm+".decerr");
	sc_trace(tf, ob.slverr, nm+".slverr");
	sc_trace(tf, ob.okay,   nm+".okay");
}

#endif // _PORT_DMA_H
