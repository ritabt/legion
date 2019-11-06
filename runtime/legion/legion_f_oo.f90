module legion_fortran_object_oriented
  use, intrinsic :: iso_c_binding
  use legion_fortran_types
  use legion_fortran_c_interface
  implicit none
  
  ! ===============================================================================
  ! DomainPoint
  ! ===============================================================================
  type FDomainPoint
    type(legion_domain_point_f_t) :: point
  contains
    procedure :: get_point_1d => legion_domain_point_get_point_1d
    procedure :: get_point_2d => legion_domain_point_get_point_2d
    procedure :: get_point_3d => legion_domain_point_get_point_3d
  end type FDomainPoint
  
  interface FDomainPoint
    module procedure legion_domain_point_constructor_point_1d
    module procedure legion_domain_point_constructor_point_2d
    module procedure legion_domain_point_constructor_point_3d
  end interface
  
  ! ===============================================================================
  ! Point
  ! ===============================================================================
  type FPoint
    integer :: dim
  end type FPoint

  type, extends(FPoint) :: FPoint1D
    type(legion_point_1d_f_t) :: point
  end type FPoint1D
  
  type, extends(FPoint) :: FPoint2D
    type(legion_point_2d_f_t) :: point
  end type FPoint2D
  
  type, extends(FPoint) :: FPoint3D
    type(legion_point_3d_f_t) :: point
  end type FPoint3D
  
  interface FPoint1D
    module procedure legion_point_1d_constructor_integer4
    module procedure legion_point_1d_constructor_integer8
  end interface
  
  interface FPoint2D
    module procedure legion_point_2d_constructor_integer4
    module procedure legion_point_2d_constructor_integer8
  end interface
  
  interface FPoint3D
    module procedure legion_point_3d_constructor_integer4
    module procedure legion_point_3d_constructor_integer8
  end interface
  
  ! ===============================================================================
  ! Rect
  ! ===============================================================================
  type FDomain
    type(legion_domain_f_t) :: domain
  end type FDomain
  
  ! ===============================================================================
  ! Rect
  ! ===============================================================================
  type FRect1D
    type(legion_rect_1d_f_t) :: rect
  end type FRect1D
  
  type FRect2D
    type(legion_rect_2d_f_t) :: rect
  end type FRect2D
  
  type FRect3D
    type(legion_rect_3d_f_t) :: rect
  end type FRect3D
  
  interface FRect1D
    module procedure legion_rect_1d_constructor_integer4
    module procedure legion_rect_1d_constructor_integer8
    module procedure legion_rect_1d_constructor_point_1d
  end interface
  
  interface FRect2D
    module procedure legion_rect_2d_constructor_point_2d
  end interface
  
  interface FRect3D
    module procedure legion_rect_3d_constructor_point_3d
  end interface
  
  interface assignment (=)
    module procedure legion_rect_1d_assignment_from_domain
  end interface
  
  ! ===============================================================================
  ! FieldAccessor
  ! ===============================================================================
  type FFieldAccessor
    integer :: dim
    integer(c_size_t) :: data_size
  contains
    procedure :: init => legion_field_accessor_init
    procedure, private :: legion_field_accessor_read_point_ptr
    procedure, private :: legion_field_accessor_read_point_integer4
    procedure, private :: legion_field_accessor_read_point_integer8
    procedure, private :: legion_field_accessor_read_point_real4
    procedure, private :: legion_field_accessor_read_point_real8
    procedure, private :: legion_field_accessor_read_point_complex4
    procedure, private :: legion_field_accessor_read_point_complex8
    procedure, private :: legion_field_accessor_write_point_ptr
    procedure, private :: legion_field_accessor_write_point_integer4
    procedure, private :: legion_field_accessor_write_point_integer8
    procedure, private :: legion_field_accessor_write_point_real4
    procedure, private :: legion_field_accessor_write_point_real8
    procedure, private :: legion_field_accessor_write_point_complex4
    procedure, private :: legion_field_accessor_write_point_complex8
    generic :: read_point => legion_field_accessor_read_point_ptr, &
                             legion_field_accessor_read_point_integer4, legion_field_accessor_read_point_integer8, &
                             legion_field_accessor_read_point_real4, legion_field_accessor_read_point_real8, &
                             legion_field_accessor_read_point_complex4, legion_field_accessor_read_point_complex8
    generic :: write_point => legion_field_accessor_write_point_ptr, &
                              legion_field_accessor_write_point_integer4, legion_field_accessor_write_point_integer8, &
                              legion_field_accessor_write_point_real4, legion_field_accessor_write_point_real8, &
                              legion_field_accessor_write_point_complex4, legion_field_accessor_write_point_complex8
  end type FFieldAccessor

  type, extends(FFieldAccessor) :: FFieldAccessor1D
    type(legion_accessor_array_1d_f_t) :: accessor
  end type FFieldAccessor1D
  
  type, extends(FFieldAccessor) :: FFieldAccessor2D
    type(legion_accessor_array_2d_f_t) :: accessor
  end type FFieldAccessor2D
  
  type, extends(FFieldAccessor) :: FFieldAccessor3D
    type(legion_accessor_array_3d_f_t) :: accessor
  end type FFieldAccessor3D
  
  interface FFieldAccessor1D
    module procedure legion_field_accessor_1d_constructor
  end interface
  
  interface FFieldAccessor2D
    module procedure legion_field_accessor_2d_constructor
  end interface
  
  interface FFieldAccessor3D
    module procedure legion_field_accessor_3d_constructor
  end interface
  
  ! ===============================================================================
  ! FDomainPointIterator
  ! ===============================================================================
  type FDomainPointIterator
    type(legion_domain_point_iterator_f_t) :: iterator    
  contains
    ! @see Legion::Domain::DomainPointIterator::step()
    procedure :: step => legion_domain_point_iterator_step
    
    ! @see Legion::Domain::DomainPointIterator::any_left
    procedure :: has_next => legion_domain_point_iterator_has_next
    
    ! @see Legion::Domain::DomainPointIterator::~DomainPointIterator()
    procedure :: destroy => legion_domain_point_iterator_destructor
      
  end type FDomainPointIterator
  
  interface FDomainPointIterator
    ! @see Legion::Domain::DomainPointIterator::DomainPointIterator()
    module procedure legion_domain_point_iterator_constructor_from_domain
    module procedure legion_domain_point_iterator_constructor_from_rect_1d
  end interface 
  
  ! ===============================================================================
  ! IndexSpace
  ! ===============================================================================
  type FIndexSpace
    type(legion_index_space_f_t) :: is
  end type FIndexSpace
  
  ! ===============================================================================
  ! FieldSpace
  ! ===============================================================================
  type FFieldSpace
    type(legion_field_space_f_t) :: fs
  end type FFieldSpace
  
  ! ===============================================================================
  ! FieldAllocator
  ! ===============================================================================
  type FFieldAllocator
    type(legion_field_allocator_f_t) :: fa
  contains
    ! @see Legion::FieldAllocator::allocate_field()
    procedure :: allocate_field => legion_field_allocator_allocate_field
    
    ! @see Legion::FieldAllocator::free_field()
    procedure :: free_field => legion_field_allocator_free_field
    
    ! @see Legion::FieldAllocator::~FieldAllocator()
    procedure :: destroy => legion_field_allocator_destroy
  end type FFieldAllocator
  
  ! ===============================================================================
  ! IndexPartition
  ! ===============================================================================
  type FIndexPartition
    type(legion_index_partition_f_t) :: ip
  end type FIndexPartition
  
  ! ===============================================================================
  ! LogicalRegion
  ! ===============================================================================
  type FLogicalRegion
    type(legion_logical_region_f_t) :: lr
  contains
    ! @see Legion::LogicalRegion::get_index_space
    procedure :: get_index_space => legion_logical_region_get_index_space
  end type FLogicalRegion
  
  ! ===============================================================================
  ! LogicalPartition
  ! ===============================================================================
  type FLogicalPartition
    type(legion_logical_partition_f_t) :: lp
  end type FLogicalPartition
  
  ! ===============================================================================
  ! PhysicalRegion
  ! ===============================================================================
  type FPhysicalRegion
    type(legion_physical_region_f_t) :: pr
  end type FPhysicalRegion
  
  ! ===============================================================================
  ! PhysicalRegionList
  ! ===============================================================================
  type FPhysicalRegionList
    type(c_ptr) :: region_ptr
    integer :: num_regions
  contains
    procedure :: size => legion_physical_region_list_size
    procedure :: get_region => legion_physical_region_list_get_region_by_id
  end type FPhysicalRegionList
  
  ! ===============================================================================
  ! RegionRequirement
  ! ===============================================================================
  type FRegionRequirement
    type(legion_region_requirement_f_t) :: rr
  contains
    ! @see Legion::RegionRequirement::region
    procedure :: get_region => legion_region_requirement_get_logical_region
    
    ! @see Legion::RegionRequirement::privilege_fields
    procedure :: get_privilege_field => legion_region_requirement_get_privilege_field_by_id
  end type FRegionRequirement
  
  ! ===============================================================================
  ! Future
  ! ===============================================================================
  type FFuture
    type(legion_future_f_t) :: future
  end type FFuture
  
  ! ===============================================================================
  ! FutureMap
  ! ===============================================================================
  type FFutureMap
    type(legion_future_map_f_t) :: future_map
  end type FFutureMap
  
  ! ===============================================================================
  ! TaskArgument
  ! ===============================================================================
  type FTaskArgument
    type(legion_task_argument_f_t) :: task_arg
  end type FTaskArgument
  
  interface FTaskArgument
    module procedure legion_task_argument_constructor
  end interface
  
  ! ===============================================================================
  ! ArgumentMap
  ! ===============================================================================
  type FArgumentMap
    type(legion_argument_map_f_t) :: arg_map
  end type FArgumentMap
  
  interface FArgumentMap
    module procedure legion_argument_map_constructor
  end interface
  
  ! ===============================================================================
  ! TaskLauncher
  ! ===============================================================================
  type FTaskLauncher
    type(legion_task_launcher_f_t) launcher
  contains
    procedure, private :: legion_task_launcher_add_region_requirement
    
    ! @see Legion::TaskLauncher::add_region_requirement()  
    generic :: add_region_requirement => legion_task_launcher_add_region_requirement
    
    ! @see Legion::TaskLauncher::add_field()
    procedure :: add_field => legion_task_launcher_add_field
    
    ! Legion::TaskLauncher::~TaskLauncher()
    procedure :: destroy => legion_task_launcher_destructor
  end type FTaskLauncher
  
  interface FTaskLauncher
    module procedure legion_task_launcher_constructor
  end interface
  
  ! ===============================================================================
  ! IndexLauncher
  ! ===============================================================================
  type FIndexLauncher
    type(legion_index_launcher_f_t) index_launcher
  contains
    procedure, private :: legion_index_launcher_add_region_requirement_logical_partition
    
    ! @see Legion::IndexTaskLauncher::add_region_requirement()  
    generic :: add_region_requirement => legion_index_launcher_add_region_requirement_logical_partition
    
    ! @see Legion::IndexLaunchxer::add_field()
    procedure :: add_field => legion_index_launcher_add_field
    
    ! @see Legion::IndexTaskLauncher::~IndexTaskLauncher()
    procedure :: destroy => legion_index_launcher_destructor
  end type FIndexLauncher
  
  interface FIndexLauncher
    module procedure legion_index_launcher_constructor_from_index_space
  end interface
  
  ! ===============================================================================
  ! Task
  ! ===============================================================================
  type FTask
    type(legion_task_f_t) :: task
  contains
    ! @see Legion::Task::regions
    procedure :: get_region_requirement => legion_task_get_region_requirement_by_id
    
    ! @see Legion::Task::arglen
    procedure :: get_arglen=> legion_task_get_arglen
    
    ! @see Legion::Task::args
    procedure :: get_args => legion_task_get_args
  end type FTask
  
  ! ===============================================================================
  ! Runtime
  ! ===============================================================================
  type FRuntime
    type(legion_runtime_f_t) :: runtime
  contains
    procedure, private :: legion_runtime_create_index_space_from_elmts_size
    procedure, private :: legion_runtime_create_index_space_from_domain
    procedure, private :: legion_runtime_create_index_space_from_rect_1d
    
    ! @see Legion::Runtime::get_index_space_domain()
    procedure :: get_index_space_domain => legion_runtime_get_index_domain_return_domain
                                         
    ! @see Legion::Runtime::create_index_space()
    generic :: create_index_space => legion_runtime_create_index_space_from_elmts_size, &
                                     legion_runtime_create_index_space_from_domain, &
                                     legion_runtime_create_index_space_from_rect_1d
    
    ! @see Legion::Runtime::destroy_index_space()
    procedure :: destroy_index_space => legion_runtime_destroy_index_space
    
    ! @see Legion::Runtime::create_field_space()
    procedure :: create_field_space => legion_runtime_create_field_space 
    
    ! @see Legion::Runtime::destroy_field_space()
    procedure :: destroy_field_space => legion_runtime_destroy_field_space
    
    ! @see Legion::Runtime::create_field_allocator()
    procedure :: create_field_allocator => legion_runtime_create_field_allocator
    
    ! @see Legion::Runtime::create_logical_region()
    procedure :: create_logical_region => legion_runtime_create_logical_region
    
    ! @see Legion::Runtime::destroy_logical_region()
    procedure :: destroy_logical_region => legion_runtime_destroy_logical_region
    
    ! @see Legion::Runtime::create_equal_partition()
    procedure :: create_equal_partition => legion_runtime_create_equal_partition
    
    ! @see Legion::Runtime::get_logical_partition()
    procedure :: get_logical_partition => legion_runtime_get_logical_partition
    
    ! @see Legion::Runtime::execute_task()
    procedure :: execute_task => legion_runtime_execute_task
    
    ! @see Legion::Runtime::execute_index_space(Context, const IndexTaskLauncher &)
    procedure :: execute_index_space => legion_runtime_execute_index_space
  end type FRuntime
  
  type FContext
    type(legion_context_f_t) :: context
  end type FContext
  
  Type CellReal8
    real(kind=8), dimension(:), pointer :: y
  end type CellReal8

  type LegionArray2DReal8
    type(CellReal8), dimension(3) :: x
    integer :: dim_x
    integer :: dim_y
    integer :: ld
  end type LegionArray2DReal8
  
  interface LegionArray2DReal8
    module procedure legion_array_2d_real8_constructor
  end interface
  
contains
  
  ! ===============================================================================
  ! DomainPoint
  ! ===============================================================================
  function legion_domain_point_constructor_point_1d(point)
    implicit none
    
    type(FDomainPoint)         :: legion_domain_point_constructor_point_1d
    type(FPoint1D), intent(in) :: point
      
    legion_domain_point_constructor_point_1d%point = legion_domain_point_from_point_1d_c(point%point)
  end function legion_domain_point_constructor_point_1d
  
  function legion_domain_point_constructor_point_2d(point)
    implicit none
    
    type(FDomainPoint)         :: legion_domain_point_constructor_point_2d
    type(FPoint2D), intent(in) :: point
      
    legion_domain_point_constructor_point_2d%point = legion_domain_point_from_point_2d_c(point%point)
  end function legion_domain_point_constructor_point_2d
  
  function legion_domain_point_constructor_point_3d(point)
    implicit none
    
    type(FDomainPoint)         :: legion_domain_point_constructor_point_3d
    type(FPoint3D), intent(in) :: point
      
    legion_domain_point_constructor_point_3d%point = legion_domain_point_from_point_3d_c(point%point)
  end function legion_domain_point_constructor_point_3d
  
  function legion_domain_point_get_point_1d(this)
    implicit none
    
    type(FPoint1D)                  :: legion_domain_point_get_point_1d
    class(FDomainPoint), intent(in) :: this
    
    if (this%point%dim .ne. 1) then
      print *, "Wrong DIM 1", this%point%dim 
    end if
    legion_domain_point_get_point_1d%point = legion_domain_point_get_point_1d_c(this%point)
  end function legion_domain_point_get_point_1d
  
  function legion_domain_point_get_point_2d(this)
    implicit none
    
    type(FPoint2D)                  :: legion_domain_point_get_point_2d
    class(FDomainPoint), intent(in) :: this
    
    if (this%point%dim .ne. 2) then
      print *, "Wrong DIM 2", this%point%dim 
    end if
    legion_domain_point_get_point_2d%point = legion_domain_point_get_point_2d_c(this%point)
  end function legion_domain_point_get_point_2d
  
  function legion_domain_point_get_point_3d(this)
    implicit none
    
    type(FPoint3D)                  :: legion_domain_point_get_point_3d
    class(FDomainPoint), intent(in) :: this
    
    if (this%point%dim .ne. 3) then
      print *, "Wrong DIM 3", this%point%dim 
    end if
    legion_domain_point_get_point_3d%point = legion_domain_point_get_point_3d_c(this%point)
  end function legion_domain_point_get_point_3d  
  
  ! ===============================================================================
  ! Point
  ! ===============================================================================
  function legion_point_1d_constructor_integer4(x)
    implicit none
    
    type(FPoint1D)              :: legion_point_1d_constructor_integer4
    integer(kind=4), intent(in) :: x
    
    legion_point_1d_constructor_integer4%point%x(0) = int(x, 8)
      
  end function legion_point_1d_constructor_integer4
  
  function legion_point_1d_constructor_integer8(x)
    implicit none
    
    type(FPoint1D)              :: legion_point_1d_constructor_integer8
    integer(kind=8), intent(in) :: x
    
    legion_point_1d_constructor_integer8%point%x(0) = x
      
  end function legion_point_1d_constructor_integer8
  
  function legion_point_2d_constructor_integer4(x, y)
    implicit none
    
    type(FPoint2D)              :: legion_point_2d_constructor_integer4
    integer(kind=4), intent(in) :: x
    integer(kind=4), intent(in) :: y
    
    legion_point_2d_constructor_integer4%point%x(0) = int(x, 8)
    legion_point_2d_constructor_integer4%point%x(1) = int(y, 8)
      
  end function legion_point_2d_constructor_integer4
  
  function legion_point_2d_constructor_integer8(x, y)
    implicit none
    
    type(FPoint2D)              :: legion_point_2d_constructor_integer8
    integer(kind=8), intent(in) :: x
    integer(kind=8), intent(in) :: y
    
    legion_point_2d_constructor_integer8%point%x(0) = x
    legion_point_2d_constructor_integer8%point%x(1) = y
      
  end function legion_point_2d_constructor_integer8
  
  function legion_point_3d_constructor_integer4(x, y, z)
    implicit none
    
    type(FPoint3D)              :: legion_point_3d_constructor_integer4
    integer(kind=4), intent(in) :: x
    integer(kind=4), intent(in) :: y
    integer(kind=4), intent(in) :: z
    
    legion_point_3d_constructor_integer4%point%x(0) = int(x, 8)
    legion_point_3d_constructor_integer4%point%x(1) = int(y, 8)
    legion_point_3d_constructor_integer4%point%x(2) = int(z, 8)
      
  end function legion_point_3d_constructor_integer4
  
  function legion_point_3d_constructor_integer8(x, y, z)
    implicit none
    
    type(FPoint3D)              :: legion_point_3d_constructor_integer8
    integer(kind=8), intent(in) :: x
    integer(kind=8), intent(in) :: y
    integer(kind=8), intent(in) :: z
    
    legion_point_3d_constructor_integer8%point%x(0) = x
    legion_point_3d_constructor_integer8%point%x(1) = y
    legion_point_3d_constructor_integer8%point%x(2) = z
      
  end function legion_point_3d_constructor_integer8
  
  ! ===============================================================================
  ! Rect
  ! ===============================================================================
  function legion_rect_1d_constructor_integer4(x, y)
    implicit none
    
    type(FRect1D)               :: legion_rect_1d_constructor_integer4
    integer(kind=4), intent(in) :: x
    integer(kind=4), intent(in) :: y
    
    legion_rect_1d_constructor_integer4%rect%lo%x(0) = x
    legion_rect_1d_constructor_integer4%rect%hi%x(0) = y
  end function legion_rect_1d_constructor_integer4
  
  function legion_rect_1d_constructor_integer8(x, y)
    implicit none
    
    type(FRect1D)               :: legion_rect_1d_constructor_integer8
    integer(kind=8), intent(in) :: x
    integer(kind=8), intent(in) :: y
    
    legion_rect_1d_constructor_integer8%rect%lo%x(0) = x
    legion_rect_1d_constructor_integer8%rect%hi%x(0) = y
  end function legion_rect_1d_constructor_integer8
  
  function legion_rect_1d_constructor_point_1d(x, y)
    implicit none
    
    type(FRect1D)              :: legion_rect_1d_constructor_point_1d
    type(FPoint1D), intent(in) :: x
    type(FPoint1D), intent(in) :: y
    
    legion_rect_1d_constructor_point_1d%rect%lo = x%point
    legion_rect_1d_constructor_point_1d%rect%hi = y%point
  end function legion_rect_1d_constructor_point_1d
  
  function legion_rect_2d_constructor_point_2d(x, y)
    implicit none
    
    type(FRect2D)              :: legion_rect_2d_constructor_point_2d
    type(FPoint2D), intent(in) :: x
    type(FPoint2D), intent(in) :: y
    
    legion_rect_2d_constructor_point_2d%rect%lo = x%point
    legion_rect_2d_constructor_point_2d%rect%hi = y%point
  end function legion_rect_2d_constructor_point_2d
  
  function legion_rect_3d_constructor_point_3d(x, y)
    implicit none
    
    type(FRect3D)              :: legion_rect_3d_constructor_point_3d
    type(FPoint3D), intent(in) :: x
    type(FPoint3D), intent(in) :: y
    
    legion_rect_3d_constructor_point_3d%rect%lo = x%point
    legion_rect_3d_constructor_point_3d%rect%hi = y%point
  end function legion_rect_3d_constructor_point_3d
  
  subroutine legion_rect_1d_assignment_from_domain(rect, domain)
    implicit none
    
    type(FRect1D), intent(out) :: rect
    type(FDomain), intent(in) :: domain
      
    rect%rect = legion_domain_get_rect_1d_c(domain%domain)
  end subroutine legion_rect_1d_assignment_from_domain

  ! ===============================================================================
  ! FieldAccessor
  ! ===============================================================================
  function legion_field_accessor_1d_constructor(physical_region, fid, data_size)
    implicit none
    
    type(FFieldAccessor1D)            :: legion_field_accessor_1d_constructor
    type(FPhysicalRegion), intent(in) :: physical_region
    integer, intent(in)               :: fid
    integer(c_size_t), intent(in)     :: data_size
    

    legion_field_accessor_1d_constructor%dim = 1
    legion_field_accessor_1d_constructor%data_size = data_size
    legion_field_accessor_1d_constructor%accessor = legion_physical_region_get_field_accessor_array_1d_c(physical_region%pr, fid)
  end function legion_field_accessor_1d_constructor
  
  function legion_field_accessor_2d_constructor(physical_region, fid, data_size)
    implicit none
    
    type(FFieldAccessor2D)            :: legion_field_accessor_2d_constructor
    type(FPhysicalRegion), intent(in) :: physical_region
    integer, intent(in)               :: fid
    integer(c_size_t), intent(in)     :: data_size
    

    legion_field_accessor_2d_constructor%dim = 2
    legion_field_accessor_2d_constructor%data_size = data_size
    legion_field_accessor_2d_constructor%accessor = legion_physical_region_get_field_accessor_array_2d_c(physical_region%pr, fid)
  end function legion_field_accessor_2d_constructor
  
  function legion_field_accessor_3d_constructor(physical_region, fid, data_size)
    implicit none
    
    type(FFieldAccessor3D)            :: legion_field_accessor_3d_constructor
    type(FPhysicalRegion), intent(in) :: physical_region
    integer, intent(in)               :: fid
    integer(c_size_t), intent(in)     :: data_size
    

    legion_field_accessor_3d_constructor%dim = 3
    legion_field_accessor_3d_constructor%data_size = data_size
    legion_field_accessor_3d_constructor%accessor = legion_physical_region_get_field_accessor_array_3d_c(physical_region%pr, fid)
  end function legion_field_accessor_3d_constructor
      
  subroutine legion_field_accessor_init(this, physical_region, fid, data_size)
    implicit none
    
    class(FFieldAccessor), intent(inout)         :: this
    type(legion_physical_region_f_t), intent(in) :: physical_region
    integer, intent(in)                          :: fid
    integer(c_size_t), intent(in)                :: data_size
    
    select type (this)
    type is (FFieldAccessor1D)
      ! 1D
      this%dim = 1
      this%data_size = data_size
      this%accessor = legion_physical_region_get_field_accessor_array_1d_c(physical_region, fid)
    type is (FFieldAccessor2D)
      ! 2D
      this%dim = 2
      this%data_size = data_size
      this%accessor = legion_physical_region_get_field_accessor_array_2d_c(physical_region, fid)
    type is (FFieldAccessor3D)
      ! 3D
      this%dim = 3
      this%data_size = data_size
      this%accessor = legion_physical_region_get_field_accessor_array_3d_c(physical_region, fid)
    class default
      ! give error for unexpected/unsupported type
      stop 'initialize: unexpected type for LegionFieldAccessor object!'
    end select
  end subroutine legion_field_accessor_init
  
  subroutine legion_field_accessor_read_point_ptr(this, point, dst)
    implicit none
    
    class(FFieldAccessor), intent(in) :: this
    class(FPoint), intent(in)         :: point
    type(c_ptr)                       :: dst 
    
    select type (this)
    type is (FFieldAccessor1D)
      ! 1D
      select type (point)
      type is (FPoint1D)
        call legion_accessor_array_1d_read_point_c(this%accessor, point%point, dst, this%data_size)
      end select
    type is (FFieldAccessor2D)
      ! 2D
      select type (point)
      type is (FPoint2D)
        call legion_accessor_array_2d_read_point_c(this%accessor, point%point, dst, this%data_size)
      end select
    type is (FFieldAccessor3D)
      ! 3D
      select type (point)
      type is (FPoint3D)
        call legion_accessor_array_3d_read_point_c(this%accessor, point%point, dst, this%data_size)
      end select
    class default
      ! give error for unexpected/unsupported type
      stop 'initialize: unexpected type for LegionFieldAccessor object!'
    end select
  end subroutine legion_field_accessor_read_point_ptr
  
  subroutine legion_field_accessor_read_point_integer4(this, point, dst)
    implicit none
    
    class(FFieldAccessor), intent(in)    :: this
    class(FPoint), intent(in)            :: point
    integer(kind=4), target, intent(out) :: dst
    
    call legion_field_accessor_read_point_ptr(this, point, c_loc(dst))
  end subroutine legion_field_accessor_read_point_integer4
  
  subroutine legion_field_accessor_read_point_integer8(this, point, dst)
    implicit none
    
    class(FFieldAccessor), intent(in)    :: this
    class(FPoint), intent(in)            :: point
    integer(kind=8), target, intent(out) :: dst
    
    call legion_field_accessor_read_point_ptr(this, point, c_loc(dst))
  end subroutine legion_field_accessor_read_point_integer8
  
  subroutine legion_field_accessor_read_point_real4(this, point, dst)
    implicit none
    
    class(FFieldAccessor), intent(in) :: this
    class(FPoint), intent(in)         :: point
    real(kind=4), target, intent(out) :: dst
    
    call legion_field_accessor_read_point_ptr(this, point, c_loc(dst))
  end subroutine legion_field_accessor_read_point_real4
  
  subroutine legion_field_accessor_read_point_real8(this, point, dst)
    implicit none
    
    class(FFieldAccessor), intent(in) :: this
    class(FPoint), intent(in)         :: point
    real(kind=8), target, intent(out) :: dst
    
    call legion_field_accessor_read_point_ptr(this, point, c_loc(dst))
  end subroutine legion_field_accessor_read_point_real8
  
  subroutine legion_field_accessor_read_point_complex4(this, point, dst)
    implicit none
    
    class(FFieldAccessor), intent(in)    :: this
    class(FPoint), intent(in)            :: point
    complex(kind=4), target, intent(out) :: dst
    
    call legion_field_accessor_read_point_ptr(this, point, c_loc(dst))
  end subroutine legion_field_accessor_read_point_complex4
  
  subroutine legion_field_accessor_read_point_complex8(this, point, dst)
    implicit none
    
    class(FFieldAccessor), intent(in)    :: this
    class(FPoint), intent(in)            :: point
    complex(kind=8), target, intent(out) :: dst
    
    call legion_field_accessor_read_point_ptr(this, point, c_loc(dst))
  end subroutine legion_field_accessor_read_point_complex8
    
  subroutine legion_field_accessor_write_point_ptr(this, point, src)
    implicit none

    class(FFieldAccessor), intent(in) :: this
    class(FPoint), intent(in)         :: point
    type(c_ptr), intent(in)           :: src
    
    select type (this)
    type is (FFieldAccessor1D)
      ! 1D
      select type (point)
      type is (FPoint1D)
        call legion_accessor_array_1d_write_point_c(this%accessor, point%point, src, this%data_size)
      end select
    type is (FFieldAccessor2D)
      ! 2D
      select type (point)
      type is (FPoint2D)
        call legion_accessor_array_2d_write_point_c(this%accessor, point%point, src, this%data_size)
      end select
    type is (FFieldAccessor3D)
      ! 3D
      select type (point)
      type is (FPoint3D)
        call legion_accessor_array_3d_write_point_c(this%accessor, point%point, src, this%data_size)
      end select
    class default
      ! give error for unexpected/unsupported type
         stop 'initialize: unexpected type for LegionFieldAccessor object!'
    end select
  end subroutine legion_field_accessor_write_point_ptr
  
  subroutine legion_field_accessor_write_point_integer4(this, point, src)
    implicit none

    class(FFieldAccessor), intent(in)   :: this
    class(FPoint), intent(in)           :: point
    integer(kind=4), target, intent(in) :: src
    
    call legion_field_accessor_write_point_ptr(this, point, c_loc(src))
  end subroutine legion_field_accessor_write_point_integer4
  
  subroutine legion_field_accessor_write_point_integer8(this, point, src)
    implicit none

    class(FFieldAccessor), intent(in)   :: this
    class(FPoint), intent(in)           :: point
    integer(kind=8), target, intent(in) :: src
    
    call legion_field_accessor_write_point_ptr(this, point, c_loc(src))
  end subroutine legion_field_accessor_write_point_integer8
  
  subroutine legion_field_accessor_write_point_real4(this, point, src)
    implicit none

    class(FFieldAccessor), intent(in) :: this
    class(FPoint), intent(in)         :: point
    real(kind=4), target, intent(in)  :: src
    
    call legion_field_accessor_write_point_ptr(this, point, c_loc(src))
  end subroutine legion_field_accessor_write_point_real4
  
  subroutine legion_field_accessor_write_point_real8(this, point, src)
    implicit none

    class(FFieldAccessor), intent(in) :: this
    class(FPoint), intent(in)         :: point
    real(kind=8), target, intent(in)  :: src
    
    call legion_field_accessor_write_point_ptr(this, point, c_loc(src))
  end subroutine legion_field_accessor_write_point_real8
  
  subroutine legion_field_accessor_write_point_complex4(this, point, src)
    implicit none

    class(FFieldAccessor), intent(in)   :: this
    class(FPoint), intent(in)           :: point
    complex(kind=4), target, intent(in) :: src
    
    call legion_field_accessor_write_point_ptr(this, point, c_loc(src))
  end subroutine legion_field_accessor_write_point_complex4
  
  subroutine legion_field_accessor_write_point_complex8(this, point, src)
    implicit none

    class(FFieldAccessor), intent(in)   :: this
    class(FPoint), intent(in)           :: point
    complex(kind=8), target, intent(in) :: src
    
    call legion_field_accessor_write_point_ptr(this, point, c_loc(src))
  end subroutine legion_field_accessor_write_point_complex8
  
  function legion_array_2d_real8_constructor(raw_ptr, num_rows, num_columns, ld)
    implicit none
    
    type(LegionArray2DReal8)                 :: legion_array_2d_real8_constructor
    type(c_ptr), intent(in)                  :: raw_ptr
    integer, intent(in)                      :: num_rows
    integer, intent(in)                      :: num_columns
    type(legion_byte_offset_f_t), intent(in) :: ld
        
    type(c_ptr), allocatable :: ptr_columns(:)
    type(LegionArray2DReal8) :: tmp_2d_array
    real(kind=8), pointer :: column(:)
    real(kind=8), target :: col(10)
    integer :: i
    type(CellReal8), allocatable :: matrix(:)
    
    allocate(matrix(num_columns))
    
 !   allocate(tmp_2d_array%x(1:num_columns))
    col(1:10) = 1
    tmp_2d_array%x(1)%y(1:10) => col
    matrix(1)%y =>col
    column => col
        
    tmp_2d_array%dim_x = num_columns
    tmp_2d_array%dim_y = num_rows
    tmp_2d_array%ld = ld%offset
    allocate(ptr_columns(num_columns))
    call legion_convert_1d_to_2d_column_major_c(raw_ptr, ptr_columns, ld, num_columns)
    do i = 1, num_columns
      call c_f_pointer(ptr_columns(i), column, [num_rows])
      call c_f_pointer(ptr_columns(i), tmp_2d_array%x(i)%y, [num_rows])
    end do
    legion_array_2d_real8_constructor = tmp_2d_array
  end function legion_array_2d_real8_constructor
  
  ! ===============================================================================
  ! DomainPointIterator
  ! ===============================================================================
  function legion_domain_point_iterator_constructor_from_domain(handle)
    implicit none
    
    type(FDomainPointIterator) :: legion_domain_point_iterator_constructor_from_domain
    class(FDomain), intent(in) :: handle
      
    legion_domain_point_iterator_constructor_from_domain%iterator = &
      legion_domain_point_iterator_create_c(handle%domain)
  end function legion_domain_point_iterator_constructor_from_domain
  
  function legion_domain_point_iterator_constructor_from_rect_1d(handle)
    implicit none
    
    type(FDomainPointIterator) :: legion_domain_point_iterator_constructor_from_rect_1d
    class(FRect1D), intent(in) :: handle
      
    type(legion_domain_f_t) :: domain
    
    domain = legion_domain_from_rect_1d_c(handle%rect)  
    legion_domain_point_iterator_constructor_from_rect_1d%iterator = &
      legion_domain_point_iterator_create_c(domain)
  end function legion_domain_point_iterator_constructor_from_rect_1d
  
  subroutine legion_domain_point_iterator_destructor(this)
    implicit none
    
    class(FDomainPointIterator), intent(in) :: this
    call legion_domain_point_iterator_destroy_c(this%iterator)
  end subroutine legion_domain_point_iterator_destructor
  
  function legion_domain_point_iterator_has_next(this)
    implicit none
    
    logical                                :: legion_domain_point_iterator_has_next
    class(FDomainPointIterator), intent(in) :: this
    
    legion_domain_point_iterator_has_next = legion_domain_point_iterator_has_next_c(this%iterator)
  end function legion_domain_point_iterator_has_next
  
  function legion_domain_point_iterator_step(this)
    implicit none
    
    type(FDomainPoint) :: legion_domain_point_iterator_step
    class(FDomainPointIterator), intent(in) :: this
    
    legion_domain_point_iterator_step%point = legion_domain_point_iterator_next_c(this%iterator)
  end function legion_domain_point_iterator_step
  
  ! ===============================================================================
  ! FieldAllocator
  ! ===============================================================================
  subroutine legion_field_allocator_allocate_field(this, field_size, desired_fieldid)
    implicit none
    
    class(FFieldAllocator), intent(in) :: this
    integer(c_size_t), intent(in)      :: field_size
    integer, intent(in)                :: desired_fieldid
    
    integer                            :: tmp_fid
    
    tmp_fid = legion_field_allocator_allocate_field_c(this%fa, field_size, desired_fieldid)
    if (tmp_fid == desired_fieldid) then
    else
      print *, "Field_ID allocate error", desired_fieldid, tmp_fid
      call exit(0)
    end if
  end subroutine legion_field_allocator_allocate_field
  
  subroutine legion_field_allocator_free_field(this, fid)
    implicit none
    
    class(FFieldAllocator), intent(in) :: this
    integer, intent(in)                :: fid
    
    call legion_field_allocator_free_field_c(this%fa, fid)
  end subroutine legion_field_allocator_free_field
  
  subroutine legion_field_allocator_destroy(this)
    implicit none
    
    class(FFieldAllocator), intent(in) :: this
    
    call legion_field_allocator_destroy_c(this%fa)
  end subroutine legion_field_allocator_destroy
  
  ! ===============================================================================
  ! LogicalRegion
  ! ===============================================================================
  function legion_logical_region_get_index_space(this)
    implicit none
    
    type(FIndexSpace)                 :: legion_logical_region_get_index_space 
    class(FLogicalRegion), intent(in) :: this
    
    legion_logical_region_get_index_space%is = legion_logical_region_get_index_space_c(this%lr)
  end function legion_logical_region_get_index_space
  
  ! ===============================================================================
  ! PhysicalRegionList
  ! ===============================================================================
  function legion_physical_region_list_size(this)
    implicit none
    
    type(integer)                         :: legion_physical_region_list_size
    class(FPhysicalRegionList), intent(in) :: this
      
    legion_physical_region_list_size = this%num_regions
  end function legion_physical_region_list_size
  
  function legion_physical_region_list_get_region_by_id(this, id)
    implicit none
    
    type(FPhysicalRegion)                  :: legion_physical_region_list_get_region_by_id
    class(FPhysicalRegionList), intent(in) :: this
    type(integer), intent(in)             :: id
      
    legion_physical_region_list_get_region_by_id%pr = legion_get_physical_region_by_id_c(this%region_ptr, id, this%num_regions)
  end function legion_physical_region_list_get_region_by_id
  
  ! ===============================================================================
  ! RegionRequirement
  ! ===============================================================================
  function legion_region_requirement_get_logical_region(this)
    implicit none
    
    type(FLogicalRegion)                  :: legion_region_requirement_get_logical_region
    class(FRegionRequirement), intent(in) :: this
      
    legion_region_requirement_get_logical_region%lr = legion_region_requirement_get_region_c(this%rr)
  end function legion_region_requirement_get_logical_region
  
  function legion_region_requirement_get_privilege_field_by_id(this, id)
    implicit none
    
    type(integer)                         :: legion_region_requirement_get_privilege_field_by_id
    class(FRegionRequirement), intent(in) :: this
    type(integer), intent(in)             :: id
    
    legion_region_requirement_get_privilege_field_by_id = legion_region_requirement_get_privilege_field_c(this%rr, id)
  end function legion_region_requirement_get_privilege_field_by_id
  
  ! ===============================================================================
  ! TaskArgument
  ! ===============================================================================
  function legion_task_argument_constructor(arg, arg_size)
    implicit none 
    
    type(FTaskArgument)                     :: legion_task_argument_constructor
    type(c_ptr), optional, intent(in)       :: arg
    integer(c_size_t), optional, intent(in) :: arg_size
    
    type(c_ptr) :: tmp_arg
    integer(c_size_t) :: tmp_arg_size
    
    tmp_arg = c_null_ptr
    tmp_arg_size = 0
    if (present(arg)) tmp_arg = arg
    if (present(arg_size)) tmp_arg_size = arg_size
    
    legion_task_argument_constructor%task_arg%args = tmp_arg
    legion_task_argument_constructor%task_arg%arglen = tmp_arg_size
  end function legion_task_argument_constructor
  
  ! ===============================================================================
  ! ArgumentMap
  ! ===============================================================================
  function legion_argument_map_constructor()
    implicit none
    
    type(FArgumentMap) :: legion_argument_map_constructor
      
    type(legion_argument_map_f_t) :: tmp_arg_map
      
    legion_argument_map_constructor%arg_map = tmp_arg_map
  end function legion_argument_map_constructor
  
  ! ===============================================================================
  ! TaskLauncher
  ! ===============================================================================
  function legion_task_launcher_constructor(tid, arg, pred, id, tag)
    implicit none
    
    type(FTaskLauncher)                              :: legion_task_launcher_constructor
    integer, intent(in)                              :: tid
    type(FTaskArgument), intent(in)                  :: arg
    type(legion_predicate_f_t), optional, intent(in) :: pred
    integer, optional, intent(in)                    :: id
    integer(kind=8), optional, intent(in)            :: tag
    
    type(legion_predicate_f_t) :: tmp_pred
    integer                    :: tmp_id
    integer(kind=8)            :: tmp_tag
    
    tmp_pred = legion_predicate_true_c()
    tmp_id = 0
    tmp_tag = 0
    
    if (present(pred)) tmp_pred = pred
    if (present(id)) tmp_id = id
    if (present(pred)) tmp_tag = tag
    legion_task_launcher_constructor%launcher = legion_task_launcher_create_c(tid, arg%task_arg, tmp_pred, tmp_id, tmp_tag)
  end function legion_task_launcher_constructor
  
  subroutine legion_task_launcher_destructor(this)
    implicit none
    
    class(FTaskLauncher), intent(in) :: this
    
    call legion_task_launcher_destroy_c(this%launcher)
  end subroutine legion_task_launcher_destructor
  
  subroutine legion_task_launcher_add_region_requirement(this, handle, priv, prop, parent, tag, verified)
    implicit none
    
    class(FTaskLauncher), intent(in)      :: this
    type(FLogicalRegion), intent(in)      :: handle
    integer(c_int), intent(in)            :: priv
    integer(c_int), intent(in)            :: prop
    type(FLogicalRegion), intent(in)      :: parent
    integer(kind=8), optional, intent(in) :: tag
    logical(c_bool), optional, intent(in) :: verified
    
    integer(kind=8) :: tmp_tag
    logical(c_bool) :: tmp_verified
    integer(c_int) :: rr_id
        
    tmp_tag = 0
    tmp_verified = .false.
    
    if (present(tag)) tmp_tag = tag
    if (present(verified)) tmp_verified = verified 
    rr_id = legion_task_launcher_add_region_requirement_logical_region_c(this%launcher, &
              handle%lr, priv, prop, parent%lr, tmp_tag, tmp_verified)
  end subroutine legion_task_launcher_add_region_requirement
    
  subroutine legion_task_launcher_add_field(this, idx, fid, inst)
    implicit none
    
    class(FTaskLauncher), intent(in)      :: this
    integer, intent(in)                   :: idx
    integer, intent(in)                   :: fid
    logical(c_bool), optional, intent(in) :: inst
    
    logical(c_bool) :: tmp_inst
    
    tmp_inst = .true.
    if (present(inst)) tmp_inst = inst
    
    call legion_task_launcher_add_field_c(this%launcher, idx, fid, tmp_inst)
  end subroutine legion_task_launcher_add_field
  
  ! ===============================================================================
  ! IndexLauncher
  ! ===============================================================================
  function legion_index_launcher_constructor_from_index_space(tid, launch_space, global_arg, map, &
                                                              pred, must, id, tag)
    implicit none
    
    type(FIndexLauncher) :: legion_index_launcher_constructor_from_index_space
    integer, intent(in)                              :: tid
    type(FIndexSpace), intent(in)                    :: launch_space
    type(FTaskArgument), intent(in)                  :: global_arg
    type(FArgumentMap), intent(in)                   :: map
    type(legion_predicate_f_t), optional, intent(in) :: pred
    logical(c_bool), optional, intent(in)            :: must
    integer(c_int), optional, intent(in)             :: id
    integer(c_long), optional, intent(in)            :: tag
    
    type(legion_predicate_f_t) :: tmp_pred
    logical(c_bool) :: tmp_must
    integer(c_int) :: tmp_id
    integer(c_long) :: tmp_tag
    type(legion_domain_f_t) :: domain
    type(legion_runtime_f_t) :: runtime  
    
    tmp_pred = legion_predicate_true_c()
    tmp_must = .false.
    tmp_id = 0
    tmp_tag = 0
    
    if (present(pred)) tmp_pred = pred
    if (present(must)) tmp_must = must
    if (present(id)) tmp_id = id
    if (present(tag)) tmp_tag = tag
    
    runtime = legion_runtime_get_runtime_c()
    domain = legion_index_space_get_domain_c(runtime, launch_space%is)
    
    legion_index_launcher_constructor_from_index_space%index_launcher = &
      legion_index_launcher_create_c(tid, domain, &
        global_arg%task_arg, map%arg_map, &
        tmp_pred, tmp_must, tmp_id, tmp_tag)
  end function legion_index_launcher_constructor_from_index_space
  
  subroutine legion_index_launcher_destructor(this)
    implicit none
    
    class(FIndexLauncher), intent(in) :: this
    
    call legion_index_launcher_destroy_c(this%index_launcher)
  end subroutine legion_index_launcher_destructor
  
  subroutine legion_index_launcher_add_region_requirement_logical_partition(this, handle, proj, priv, prop, parent, tag, verified)
    implicit none
    
    class(FIndexLauncher), intent(in)     :: this
    type(FLogicalPartition), intent(in)   :: handle
    integer(c_int), intent(in)            :: proj
    integer(c_int), intent(in)            :: priv
    integer(c_int), intent(in)            :: prop
    type(FLogicalRegion), intent(in)      :: parent
    integer(kind=8), optional, intent(in) :: tag
    logical(c_bool), optional, intent(in) :: verified
    
    integer(kind=8) :: tmp_tag
    logical(c_bool) :: tmp_verified
    integer(c_int) :: rr_id
        
    tmp_tag = 0
    tmp_verified = .false.
    
    if (present(tag)) tmp_tag = tag
    if (present(verified)) tmp_verified = verified 
    rr_id = legion_index_launcher_add_region_requirement_lp_c(this%index_launcher, &
              handle%lp, proj, priv, prop, parent%lr, tmp_tag, tmp_verified)
  end subroutine legion_index_launcher_add_region_requirement_logical_partition
  
  subroutine legion_index_launcher_add_field(this, idx, fid, inst)
    implicit none
    
    class(FIndexLauncher), intent(in)     :: this
    integer, intent(in)                   :: idx
    integer, intent(in)                   :: fid
    logical(c_bool), optional, intent(in) :: inst
    
    logical(c_bool) :: tmp_inst
    
    tmp_inst = .true.
    if (present(inst)) tmp_inst = inst
    
    call legion_index_launcher_add_field_c(this%index_launcher, idx, fid, tmp_inst)
  end subroutine legion_index_launcher_add_field
  
  ! ===============================================================================
  ! Task
  ! ===============================================================================
  function legion_task_get_region_requirement_by_id(this, id)
    implicit none
    
    type(FRegionRequirement)  :: legion_task_get_region_requirement_by_id
    class(FTask), intent(in)  :: this
    type(integer), intent(in) :: id
      
    legion_task_get_region_requirement_by_id%rr = legion_task_get_requirement_c(this%task, id)
    
  end function legion_task_get_region_requirement_by_id
  
  function legion_task_get_arglen(this)
    implicit none
    
    integer(kind=8)          :: legion_task_get_arglen
    class(FTask), intent(in) :: this
    
    legion_task_get_arglen = legion_task_get_arglen_c(this%task)
  end function legion_task_get_arglen
  
  function legion_task_get_args(this)
    implicit none
    
    type(c_ptr)              :: legion_task_get_args
    class(FTask), intent(in) :: this
    
    legion_task_get_args = legion_task_get_args_c(this%task)
  end function legion_task_get_args
  
  ! ===============================================================================
  ! Runtime
  ! ===============================================================================
  function legion_runtime_get_index_domain_return_domain(this, ctx, index_space)
    implicit none
    
    type(FDomain)                :: legion_runtime_get_index_domain_return_domain
    class(FRuntime), intent(in)   :: this
    type(FContext), intent(in)    :: ctx
    type(FIndexSpace), intent(in) :: index_space
    
    legion_runtime_get_index_domain_return_domain%domain = legion_index_space_get_domain_c(this%runtime, index_space%is)
  end function legion_runtime_get_index_domain_return_domain
  
  function legion_runtime_create_index_space_from_elmts_size(this, ctx, max_num_elmts)
    implicit none
    
    type(FIndexSpace)           :: legion_runtime_create_index_space_from_elmts_size
    class(FRuntime), intent(in) :: this
    type(FContext), intent(in)  :: ctx
    integer(kind=8), intent(in) :: max_num_elmts
      
    legion_runtime_create_index_space_from_elmts_size%is = legion_index_space_create_c(this%runtime, &
                                                             ctx%context, max_num_elmts)
  end function legion_runtime_create_index_space_from_elmts_size
  
  function legion_runtime_create_index_space_from_domain(this, ctx, domain)
    implicit none
    
    type(FIndexSpace)           :: legion_runtime_create_index_space_from_domain
    class(FRuntime), intent(in) :: this
    type(FContext), intent(in)  :: ctx
    type(FDomain), intent(in)   :: domain
      
    legion_runtime_create_index_space_from_domain%is = legion_index_space_create_domain_c(this%runtime, &
                                                         ctx%context, domain%domain)
  end function legion_runtime_create_index_space_from_domain
  
  function legion_runtime_create_index_space_from_rect_1d(this, ctx, rect_1d)
    implicit none
    
    type(FIndexSpace)           :: legion_runtime_create_index_space_from_rect_1d
    class(FRuntime), intent(in) :: this
    type(FContext), intent(in)  :: ctx
    type(FRect1D), intent(in)   :: rect_1d
    
    type(legion_domain_f_t) :: domain
    
    domain = legion_domain_from_rect_1d_c(rect_1d%rect)  
    legion_runtime_create_index_space_from_rect_1d%is = legion_index_space_create_domain_c(this%runtime, &
                                                          ctx%context, domain)
  end function legion_runtime_create_index_space_from_rect_1d
  
  subroutine legion_runtime_destroy_index_space(this, ctx, index_space)
    implicit none
    
    class(FRuntime), intent(in)   :: this
    type(FContext), intent(in)    :: ctx
    type(FIndexSpace), intent(in) :: index_space
    
    call legion_index_space_destroy_c(this%runtime, ctx%context, index_space%is)
  end subroutine legion_runtime_destroy_index_space
  
  function legion_runtime_create_field_space(this, ctx)   
    implicit none
    
    type(FFieldSpace)           :: legion_runtime_create_field_space
    class(FRuntime), intent(in) :: this
    type(FContext), intent(in)  :: ctx
      
    legion_runtime_create_field_space%fs = legion_field_space_create_c(this%runtime, ctx%context)
  end function legion_runtime_create_field_space
  
  subroutine legion_runtime_destroy_field_space(this, ctx, field_space)
    implicit none
    
    class(FRuntime), intent(in)   :: this
    type(FContext), intent(in)    :: ctx
    type(FFieldSpace), intent(in) :: field_space
      
    call legion_field_space_destroy_c(this%runtime, ctx%context, field_space%fs)
  end subroutine legion_runtime_destroy_field_space
  
  function legion_runtime_create_field_allocator(this, ctx, field_space)
    implicit none
    
    type(FFieldAllocator)         :: legion_runtime_create_field_allocator
    class(FRuntime), intent(in)   :: this
    type(FContext), intent(in)    :: ctx
    type(FFieldSpace), intent(in) :: field_space
      
    legion_runtime_create_field_allocator%fa = legion_field_allocator_create_c(this%runtime, ctx%context, field_space%fs)
  end function legion_runtime_create_field_allocator
  
  function legion_runtime_create_logical_region(this, ctx, index_space, field_space)
    implicit none
    
    type(FLogicalRegion)          :: legion_runtime_create_logical_region
    class(FRuntime), intent(in)   :: this
    type(FContext), intent(in)    :: ctx
    type(FIndexSpace), intent(in) :: index_space
    type(FFieldSpace), intent(in) :: field_space
      
    legion_runtime_create_logical_region%lr = legion_logical_region_create_c(this%runtime, ctx%context, &
                                                index_space%is, field_space%fs)
  end function legion_runtime_create_logical_region
  
  subroutine legion_runtime_destroy_logical_region(this, ctx, logical_region)
    implicit none
    
    class(FRuntime), intent(in)      :: this
    type(FContext), intent(in)       :: ctx
    type(FLogicalRegion), intent(in) :: logical_region
      
    call legion_logical_region_destroy_c(this%runtime, ctx%context, logical_region%lr)
  end subroutine legion_runtime_destroy_logical_region
  
  function legion_runtime_create_equal_partition(this, ctx, parent, color_space, granularity, color)
    implicit none
    
    type(FIndexPartition) :: legion_runtime_create_equal_partition
    class(FRuntime), intent(in)           :: this
    type(FContext), intent(in)            :: ctx
    type(FIndexSpace), intent(in)         :: parent
    type(FIndexSpace), intent(in)         :: color_space
    integer(kind=8), optional, intent(in) :: granularity
    integer(c_int), optional, intent(in)  :: color
    
    integer(kind=8) :: tmp_granularity = 1
    integer(c_int) :: tmp_color = 0
    
    if (present(granularity)) tmp_granularity = granularity
    if (present(color)) tmp_color = color
    
    legion_runtime_create_equal_partition%ip = legion_index_partition_create_equal_c(this%runtime, ctx%context, parent%is, &
                                                 color_space%is, tmp_granularity, tmp_color)
  end function legion_runtime_create_equal_partition
  
  function legion_runtime_get_logical_partition(this, ctx, parent, handle)
    implicit none
    
    type(FLogicalPartition)           :: legion_runtime_get_logical_partition
    class(FRuntime), intent(in)       :: this
    type(FContext), intent(in)        :: ctx
    type(FLogicalRegion), intent(in)  :: parent
    type(FIndexPartition), intent(in) :: handle
      
    legion_runtime_get_logical_partition%lp = legion_logical_partition_create_c(this%runtime, ctx%context, &
                                                parent%lr, handle%ip)
  end function legion_runtime_get_logical_partition
  
  function legion_runtime_execute_task(this, ctx, launcher)
    implicit none
    
    type(FFuture)                   :: legion_runtime_execute_task
    class(FRuntime), intent(in)     :: this
    type(FContext), intent(in)      :: ctx
    type(FTaskLauncher), intent(in) :: launcher
      
    legion_runtime_execute_task%future = legion_task_launcher_execute_c(this%runtime, ctx%context, launcher%launcher)
  end function legion_runtime_execute_task
  
  function legion_runtime_execute_index_space(this, ctx, launcher)
    implicit none
    
    type(FFutureMap)                :: legion_runtime_execute_index_space
    class(FRuntime), intent(in)     :: this
    type(FContext), intent(in)      :: ctx
    type(FIndexLauncher), intent(in) :: launcher
    
    legion_runtime_execute_index_space%future_map = legion_index_launcher_execute_c(this%runtime, ctx%context, &
                                                      launcher%index_launcher)
  end function legion_runtime_execute_index_space
  
  ! ================================
  subroutine legion_task_prolog(tdata, tdatalen, &
                                userdata, userlen, &
                                proc_id, &
                                task, pr_list, &
                                ctx, runtime)
    
    implicit none
                                
    type(c_ptr), intent(in)                        :: tdata ! pass reference
    integer(c_size_t), value, intent(in)           :: tdatalen
    type(c_ptr), optional, intent(in)              :: userdata ! dummy
    integer(c_size_t), value, optional, intent(in) :: userlen ! dummy
    integer(c_long_long), value, intent(in)        :: proc_id
    type(FTask), intent(out)                       :: task ! pass reference
    type(FPhysicalRegionList), intent(out)         :: pr_list ! pass reference
    type(FContext), intent(out)                    :: ctx ! pass reference          
    type(FRuntime), intent(out)                    :: runtime ! pass reference
    
    type(c_ptr) :: tmp_userdata
    integer(c_size_t) :: tmp_userlen
    
    if (present(userdata)) tmp_userdata = c_null_ptr
    tmp_userlen = userlen
      
    call legion_task_preamble_c(tdata, tdatalen, proc_id, &
                                task%task, pr_list%region_ptr, pr_list%num_regions, &
                                ctx%context, runtime%runtime)
  end subroutine legion_task_prolog
  
  subroutine legion_task_epilog(runtime, ctx, retval, retsize)
    implicit none

    type(FRuntime), intent(in)                     :: runtime
    type(FContext), intent(in)                     :: ctx
    type(c_ptr), value, optional, intent(in)       :: retval
    integer(c_size_t), value, optional, intent(in) :: retsize
    
    type(c_ptr) :: tmp_retval
    integer(c_size_t) :: tmp_retsize
    
    tmp_retval = c_null_ptr
    tmp_retsize = 0
    if (present(retval)) tmp_retval = tmp_retval
    if (present(retsize)) tmp_retsize = retsize
  
    call legion_task_postamble_c(runtime%runtime, ctx%context, tmp_retval, tmp_retsize)
  end subroutine legion_task_epilog

end module