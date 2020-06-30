/**
 *  @file allocator.h
 */

#ifndef ALLOCATOR_H_
#define ALLOCATOR_H_

#include <new> // bad_alloc
#include "dlmalloc.h"

#define ACC_PRE(name) dl##name
#define ACC_NEW(type) new(::ACC_PRE(malloc)(sizeof(type))) (type)
#define ACC_DELETE(ptr,type) (ptr)->~type(); ::ACC_PRE(free)(ptr)
#define ACC_FREE(ptr) ::ACC_PRE(free)(ptr)

#define ACC_NS accel

namespace ACC_NS
{
  template<typename _Tp>
    class allocator;

  /// allocator<void> specialization.
  template<>
    class allocator<void>
    {
    public:
      typedef size_t      size_type;
      typedef ptrdiff_t   difference_type;
      typedef void*       pointer;
      typedef const void* const_pointer;
      typedef void        value_type;

      template<typename _Tp1>
        struct rebind
        { typedef allocator<_Tp1> other; };
    };

  /**
   *  @brief  An allocator that uses ACC_PRE(malloc), as per [20.4].
   *
   *  This is precisely the allocator defined in the C++ Standard.
   *    - all allocation calls operator new
   *    - all deallocation calls operator delete
   */
  template<typename _Tp>
    class allocator
    {
    public:
      typedef size_t     size_type;
      typedef ptrdiff_t  difference_type;
      typedef _Tp*       pointer;
      typedef const _Tp* const_pointer;
      typedef _Tp&       reference;
      typedef const _Tp& const_reference;
      typedef _Tp        value_type;

      template<typename _Tp1>
        struct rebind
        { typedef allocator<_Tp1> other; };

      allocator() throw() { }

      allocator(const allocator&) throw() { }

      template<typename _Tp1>
        allocator(const allocator<_Tp1>&) throw() { }

      ~allocator() throw() { }

      pointer
      address(reference __x) const { return &__x; }

      const_pointer
      address(const_reference __x) const { return &__x; }

      pointer
      allocate(size_type __n, const void* = 0)
      {
        void *p = ::ACC_PRE(malloc)(__n * sizeof(_Tp));
        if (p == NULL)
          throw std::bad_alloc();
        return static_cast<_Tp*>(p);
      }

      void
      deallocate(pointer __p, size_type)
      { ::ACC_PRE(free)(static_cast<void*>(__p)); }

      size_type
      max_size() const throw()
      { return size_t(-1) / sizeof(_Tp); }

      void
      construct(pointer __p, const _Tp& __val)
      { ::new(__p) _Tp(__val); }

      void
      destroy(pointer __p) { __p->~_Tp(); }
    };

  template<typename _T1, typename _T2>
    inline bool
    operator==(const allocator<_T1>&, const allocator<_T2>&)
    { return true; }

  template<typename _T1, typename _T2>
    inline bool
    operator!=(const allocator<_T1>&, const allocator<_T2>&)
    { return false; }

} // namespace

// Override global operator new and delete
#ifdef ACC_OVERRIDE_NEW

void *operator new(size_t size)
{
  void *p = ::ACC_PRE(malloc)(size);
  if (p == NULL)
    throw std::bad_alloc();
  return p;
}

void operator delete(void *p)
{
  ::ACC_PRE(free)(p);
}

void *operator new[](size_t size)
{
  void *p = ::ACC_PRE(malloc)(size);
  if (p == NULL)
    throw std::bad_alloc();
  return p;
}

void operator delete[](void *p)
{
  ::ACC_PRE(free)(p);
}

#endif // OVERRIDE_NEW

#endif // ALLOCATOR_H_
