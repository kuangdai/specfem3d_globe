!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  6 . 0
!          --------------------------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently many more authors!)
! (c) Princeton University and CNRS / University of Marseille, April 2014
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

!------------------------------------------------------------------------------------------------
! difference_sem
!
! this runs in serial, no need to submit as parallel job.
! takes the difference between proc***.bin from two different input directories
!
! usage: ./program_difference_kernel slice_list filename INPUT_dir_1/ INPUT_dir_2/ OUTPUT_DIFF/
!
!------------------------------------------------------------------------------------------------

program difference_sem

  use constants,only: CUSTOM_REAL,NGLLX,NGLLY,NGLLZ,NX_BATHY,NY_BATHY,IIN,IOUT,MAX_STRING_LEN

  implicit none

  include 'OUTPUT_FILES/values_from_mesher.h'

  integer,parameter :: MAX_NUM_NODES = 2000
  integer :: node_list(MAX_NUM_NODES)

  character(len=MAX_STRING_LEN) :: arg(6)
  character(len=MAX_STRING_LEN) :: file1name,file2name
  character(len=MAX_STRING_LEN) :: input1dir,input2dir
  character(len=MAX_STRING_LEN) :: outputdir,kernel_name
  character(len=MAX_STRING_LEN) :: sline
  character(len=20) :: reg_name

  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,NSPEC_CRUST_MANTLE) :: sem_data,sem_data_2

  real(kind=CUSTOM_REAL) :: min,max,min_rel,max_rel
  real(kind=CUSTOM_REAL) :: min_all,max_all,min_rel_all,max_rel_all

  integer :: num_node,njunk
  integer :: i, it, iproc, ier

  ! checks arguments
  do i = 1, 6
    call get_command_argument(i,arg(i))

    ! usage info
    if (i < 6 .and. trim(arg(i)) == '') then
      print *, ' '
      print *, ' Usage: difference_sem slice_list kernel_name input1_dir/ input2_dir/ output_dir/ '
      print *, ' '
      print *, ' with'
      print *, '   slice_list    - text file with slice numbers'
      print *, '   kernel_name   - takes files with this kernel name'
      print *, '                     e.g. "vsv" for proc***_reg1_vsv.bin'
      print *, '   input1_dir/   - input directory for first files'
      print *, '   input2_dir/   - input directory for second files'
      print *, '   output_dir/   - output directory for (first - second) file values'
      print *, ' '
      print *, ' possible kernel_names are: '
      print *, '   "alpha_kernel", "beta_kernel", .., "vsv", "rho_vp", "kappastore", "mustore", etc.'
      print *
      print *, '   that are stored in the local directories input1_dir/ and input2_dir/ '
      print *, '   as real(kind=CUSTOM_REAL) filename(NGLLX,NGLLY,NGLLZ,NSPEC_CRUST_MANTLE) in proc***_reg1_filename.bin'
      print *, ' '
      stop 'Reenter command line options'
    endif
  enddo

  ! get slices id
  num_node = 0
  open(unit = 20, file = trim(arg(1)), status = 'old',iostat=ier)
  if (ier /= 0) then
    print*,'Error no file: ',trim(arg(1))
    stop 'Error opening slices file'
  endif

  ! reads in slices list
  do while (1 == 1)
    read(20,'(a)',iostat=ier) sline
    if (ier /= 0) exit
    read(sline,*,iostat=ier) njunk
    if (ier /= 0) exit
    num_node = num_node + 1
    node_list(num_node) = njunk
  enddo
  close(20)
  print *, 'slice list: '
  print *, node_list(1:num_node)
  print *, ' '

  ! prefix for crust/mantle region
  reg_name = 'reg1_'

  ! gets kernel and directory names from argument call
  kernel_name = trim(reg_name) // trim(arg(2))
  input1dir = trim(arg(3))
  input2dir = trim(arg(4))
  outputdir = trim(arg(5))

  ! loops over slices
  min_all = 0.0
  max_all = 0.0
  min_rel_all = 0.0
  max_rel_all = 0.0
  do it = 1, num_node

    ! user output
    write(*,*) 'differencing files: ',it,' out of ',num_node

    iproc = node_list(it)

    write(file1name,'(a,i6.6,a)') trim(input1dir)//'/proc',iproc,'_'//trim(kernel_name)//'.bin'
    write(file2name,'(a,i6.6,a)') trim(input2dir)//'/proc',iproc,'_'//trim(kernel_name)//'.bin'

    ! reads in file from first directory
    write(*,*) '  data_1: ',trim(file1name)
    open(IIN,file=trim(file1name),status='old',form='unformatted',iostat=ier)
    if (ier /= 0 ) then
      print *,'Error opening file: ',trim(file1name)
      stop 'Error opening first data file'
    endif
    read(IIN) sem_data
    close(IIN)

    ! reads in file from second directory
    write(*,*) '  data_2: ',trim(file2name)
    open(IIN,file=trim(file2name),status='old',form='unformatted',iostat=ier)
    if (ier /= 0 ) then
      print *,'Error opening file: ',trim(file2name)
      stop 'Error opening second data file'
    endif
    read(IIN) sem_data_2
    close(IIN)

    ! user output
    write(*,*) '  min/max data_1 value: ',minval(sem_data),maxval(sem_data)
    write(*,*) '  min/max data_2 value: ',minval(sem_data_2),maxval(sem_data_2)
    write(*,*)

    ! stores difference between kernel files
    write(*,*) '  difference: (data_1 - data_2)'

    ! absolute values
    write(file1name,'(a,i6.6,a)') trim(outputdir)//'/proc',iproc,'_'//trim(kernel_name)//'_diff.bin'
    write(*,*) '  file: ',trim(file1name)
    open(IOUT,file=trim(file1name),form='unformatted',iostat=ier)
    if (ier /= 0 ) then
      print *,'Error opening file: ',trim(file1name)
      stop 'Error opening output data file'
    endif

    ! takes the difference
    sem_data = sem_data - sem_data_2

    write(IOUT) sem_data
    close(IOUT)

    ! min/max
    min = minval(sem_data)
    max = maxval(sem_data)
    if( min < min_all ) min_all = min
    if( max > max_all ) max_all = max

    ! stores relative difference (k1 - k2)/ k2 with respect to second input file
    write(file1name,'(a,i6.6,a)') trim(outputdir)//'/proc',iproc,'_'//trim(kernel_name)//'_diff_relative.bin'
    write(*,*) '  file: ',trim(file1name)
    open(IOUT,file=trim(file1name),form='unformatted',iostat=ier)
    if (ier /= 0 ) then
      print *,'Error opening file: ',trim(file1name)
      stop 'Error opening output data file'
    endif

    ! relative difference (k1 - k2)/ k2 with respect to second input file
    where( sem_data_2 /= 0.0)
      sem_data = sem_data / sem_data_2
    elsewhere
      sem_data = 0.0
    endwhere

    write(IOUT) sem_data
    close(IOUT)

    ! min/max
    min_rel = minval(sem_data)
    max_rel = maxval(sem_data)
    if( min_rel < min_rel_all ) min_rel_all = min_rel
    if( max_rel > max_rel_all ) max_rel_all = max_rel

    ! output
    write(*,*) '  min/max value         : ',min,max
    write(*,*) '  min/max relative value: ',min_rel,max_rel
    write(*,*)
  enddo

  ! user output
  write(*,*)
  write(*,*) 'statistics:'
  write(*,*) '  total min/max         : ',min_all,max_all
  write(*,*) '  total relative min/max: ',min_rel_all,max_rel_all
  write(*,*)
  write(*,*) 'done writing all difference and relative difference files'
  write(*,*) 'see output directory: ',trim(outputdir)
  write(*,*)

end program difference_sem


