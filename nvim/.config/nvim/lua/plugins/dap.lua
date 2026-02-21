return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "leoluz/nvim-dap-go",
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      local dap = require "dap"
      local ui = require "dapui"

      require("dapui").setup()
      require("dap-go").setup()

      require("lazydev").setup({
        library = { "nvim-dap-ui" },
      })

      -- Handled by nvim-dap-go
      -- dap.adapters.go = {
      --   type = "server",
      --   port = "${port}",
      --   executable = {
      --     command = "dlv",
      --     args = { "dap", "-l", "127.0.0.1:${port}" },
      --   },
      -- }

      -- ============== DEBUG ADAPTERS ================
      -- Install via Debug Adapter via Mason, then add it here
      -- C++
      dap.adapters.codelldb = {
        type = "executable",
        command = "codelldb", -- or if not in $PATH: "/absolute/path/to/codelldb"

        -- On windows you may have to uncomment this:
        -- detached = false,
      }
      dap.configurations.cpp = {
        {
          name = "Launch",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
        },
        {
          name = "Launch (file input)",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          stdio = {
            function()
              return vim.fn.input("Input file: ", vim.fn.getcwd() .. "/", "file")
            end,
            null,  -- stdout to terminal
            null,  -- stderr to terminal
          },
        },
      }

      -- ============== KEYMAPS ================
      -- Eval var under cursor
      vim.keymap.set("n", "<space>?", function()
        require("dapui").eval(nil, { enter = true })
      end)

      vim.keymap.set("n", "<F13>", dap.restart)

      vim.keymap.set('n', '<leader>dt', dap.toggle_breakpoint, { desc = 'Toggle Break' })
      vim.keymap.set('n', '<leader>dc', dap.continue, { desc = 'Continue' })
      vim.keymap.set('n', '<leader>dr', dap.restart, { desc = 'Restart' })
      vim.keymap.set('n', '<leader>dk', dap.terminate, { desc = 'Kill' })

      vim.keymap.set('n', '<S-F1>', dap.step_over, { desc = 'Step Over' })
      vim.keymap.set('n', '<S-F2>', dap.step_into, { desc = 'Step Into' })
      vim.keymap.set('n', '<S-F3>', dap.step_back, { desc = 'Step Back' })
      vim.keymap.set('n', '<S-F4>', dap.step_out, { desc = 'Step Out' })
      vim.keymap.set('n', '<leader>dl', dap.run_last, { desc = 'Run Last' })

      vim.keymap.set('n', '<leader>duu', ui.open, { desc = 'Open UI' })
      vim.keymap.set('n', '<leader>duc', ui.close, { desc = 'Close ui' })

      dap.listeners.before.attach.dapui_config = function()
        ui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        ui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        ui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        ui.close()
      end
    end,
  },
}
