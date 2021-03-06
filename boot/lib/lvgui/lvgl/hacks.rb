# FFI bindings for a couple of our hacks.
module LVGL::FFI
  # TODO: Figure out when the following struct (and this typedef) are at the
  #       end, this segfaults...
  typedef "lv_task_cb_t", "void (*lv_task_cb_t)(struct _lv_task_t *)"
  LvTask = struct! [ # {{{
    [:uint32_t, :period],
    [:uint32_t, :last_run],
    [:lv_task_cb_t, :task_cb],
    ["void *", :user_data],
    [:uint8_t, :prio],
    [:uint8_t, :once],
  ] # }}}

  extern "void hal_init()"

  # TODO: begin/rescue DLError and assume failing is we're not in simulator.
  if lv_introspection_is_simulator
    global!("int", "monitor_width")
    global!("int", "monitor_height")
  end

  extern "void lv_task_handler()"

  def handle_lv_task(lv_task_p)
    # Unwrap the lv_task struct we received
    lv_task = LvTask.new(lv_task_p.to_i)
    # This is the userdata that has been given
    userdata = lv_task.user_data
    # Side-step our inability to rehydrate an mruby Object properly
    task = LVGL::Hacks::LVTask::REGISTRY[userdata.to_i]
    # Call the task
    task.call()
  end
  bound_method! :handle_lv_task, "void handle_lv_task_(lv_task_t * task)"

  extern "lv_task_t * lv_task_create(lv_task_cb_t, uint32_t, lv_task_prio_t, void *)"
end

# FFI bindings for "hacks" for lv_lib_nanosvg
module LVGL::FFI
  # lv_lib_nanosvg/lv_nanosvg.h
  extern "void lv_nanosvg_init()"
  extern "void lv_nanosvg_resize_next_width(int)"
  extern "void lv_nanosvg_resize_next_height(int)"
end

module LVGL::Hacks
  def self.init()
    LVGL::FFI.hal_init()
    LVGL::FFI.lv_nanosvg_init()
  end

  def self.monitor_height=(v)
    if LVGL::Introspection.simulator?
      LVGL::FFI.monitor_height = v
    end
  end
  def self.monitor_width=(v)
    if LVGL::Introspection.simulator?
      LVGL::FFI.monitor_width = v
    end
  end
  def self.theme_night(hue)
    LVGL::FFI.lv_theme_set_current(
      LVGL::FFI.lv_theme_night_init(hue, 0)
    )
  end

  module LVTask
    # Temp hack...
    # I need to figure out how to use Fiddle's #to_value to rehydrate an mruby
    # Object into its proper form.
    REGISTRY = {
      # userdata pointer int value => instance
    }
    def self.create_task(period, prio, task)
      userdata = Fiddle::Pointer[task]
      REGISTRY[userdata.to_i] = task

      LVGL::FFI.lv_task_create(
        LVGL::FFI["handle_lv_task"],
        period,
        prio,
        userdata
      )
    end

    def self.handle_tasks()
      #$stderr.puts "-> handle_tasks"
      LVGL::FFI.lv_task_handler()
      #$stderr.puts "<- handle_tasks"
    end
  end
end

module LVGL::Hacks
  module LVNanoSVG
    def self.resize_next_width(width)
      LVGL::FFI.lv_nanosvg_resize_next_width(width)
    end
    def self.resize_next_height(height)
      LVGL::FFI.lv_nanosvg_resize_next_height(height)
    end
  end
end
