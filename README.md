<<<<<<< HEAD
# valve
A library for limiting rate of tasks.
=======
<h1 id="queues" align="center">valve</h1>
<div align="center">
    <img src="https://img.shields.io/badge/version-1.0.0-orange" alt="Version">
    <br/>
    <a href="https://opensource.org/licenses/MIT">
        <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License">
    </a>
    <img src="https://img.shields.io/badge/Language-Luau-2C3E50?style=&logo=lua" alt="Luau">
    <img src="https://img.shields.io/badge/Maintained%3F-Sometimes-green.svg" alt="Luau">
    <img src="https://img.shields.io/badge/Open%20Source-%E2%9D%A4-brightgreen" alt="Luau">
</div>
<div align="center">
    A library for limiting rate of tasks.
</div>

## Table of Contents
- [Table of Contents](#table-of-contents)
- [Why does this even exist?](#why-does-this-even-exist)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Basic Usage](#basic-usage)
  - [Await Usage](#await-usage)
- [API](#api)
- [Found a Bug?](#found-a-bug)
- [Contribution](#contribution)
  - [Contributing](#contributing)
  - [Guidelines](#guidelines)
- [LICENSE](#license)
- [References](#references)

## Why does this even exist?
It just spawned in my head. It is made to control how frequent a task gets called. But i think ***valve*** is a great library for tasks like http requests or datastore requests that has to have a rate.

## Features

* **Precise Rate Limiting:** Enforces a configurable execution frequency (Hz) by injecting calculated delays between tasks, preventing burst processing from overwhelming downstream systems.
* **Bounded FIFO Buffering:** Utilizes a First-In-First-Out queue with a strict capacity limit, automatically rejecting excess insertions to ensure predictable memory usage.
* **Non-Blocking Concurrency:** Offloads task processing to a dedicated thread (task.defer), allowing the main application loop to continue uninterrupted while the queue drains.
* **Thread Synchronization:** Includes await capabilities, allowing external threads to yield *and automatically resume only after the valve has finished processing its workload.
* **Result Persistence:** Optionally aggregates the return values of all successful callbacks into an outcomes table for retrieval after execution.

## Installation
To install this to your computer you have this options;

1. Clone this repository by running following command
    ```bash
    git clone https://github.com/Cod2rDude/queues
    ```
2. Get the latest release of .rbxm file from [releases](../../releases)
3. Or add this as a submodule to your project
    ```bash
    git submodule add https://github.com/Cod2rDude/queues [PATH]
    ```
Wally will be added in future.

## Usage

### Basic Usage
```lua
    local lib =  require(path.to.module)

    -- Create a new valve with rate of 20 and queue size of 5
    local myValve = lib.new(20, 5, false, false)
    -- rate, queueSize, stopOnError, saveOutcomes

    for i = 1, 5 do
        myValve:enqueue(function()
            print(string.format("This is %d'th callback", i))
        end, false)
        -- callback, runImmediate
    end

    myValve:run()   -- This is 1'th callback
                    -- This is 2'th callback
                    -- This is 3'th callback
                    -- This is 4'th callback
                    -- This is 5'th callback
```

### Await Usage
```lua
    local lib =  require(path.to.module)

    -- Create a new valve with rate of 20 and queue size of 5
    local myValve = lib.new(20, 5, false, false)

    for i = 1, 5 do
        myValve:enqueue(function()
            print(string.format("This is %d'th callback", i))
        end, false)
    end

    myValve:run()   -- This is 1'th callback
                    -- This is 2'th callback
                    -- This is 3'th callback
                    -- This is 4'th callback
                    -- This is 5'th callback

    myValve:await() 
    print("Done")   -- Will print when valve finishes.
```

## API
Please check out [source code](./src/libs/constructor.luau) for further info about api.

## Found a Bug?
If you encounter any issues or unexpected behavior, please let me know! Your feedback helps make this library more stable.

1. Check the [existing issues](../../issues) to see if it has already been reported.
2. If not, open a [new issue](../../issues/new) and describe the problem.
3. Provide a small code snippet to reproduce the bug if possible.

## Contribution
Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

### Contributing
To maintain the stability of the library, **direct commits to the main branch are restricted.** Please follow the workflow below to suggest changes:

1.  **Fork the Project:** Create your own copy of this repository.
2.  **Create a Feature Branch:**
    ```bash
    git checkout -b feature/AmazingFeature
    ```
3.  **Commit your changes:**
    ```bash
    git commit -m 'Add some AmazingFeature'
    ```
4.  **Push to branch:**
    ```bash
    git push origin feature/AmazingFeature
    ```
5.  **Open a Pull Request:** Navigate to the original repository and click "New Pull Request". Describe your changes in detail so they can be reviewed.

Once your Pull Request is merged, GitHub will automatically list you in the official "Contributors" section of the repository. (i guess so)

After a successful merge, I will also manually add your name and contribution to the table below!

### Guidelines
We appreciate contributions you will make but we will also highly appreciate you to follow our guidelines while contributing.

1.  Of course make sure your code is efficient.
2.  No nsfw links, swearing or anything like those.
3.  Maybe follow the coding style we do.
4.  That's it!

<div id="contributors">
    <h2>Contributors</h2>
    <div align="center">
        <table width="75%">
            <thead>
                <tr>
                    <th align="left">Contributor</th>
                    <th align="left">Description</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td><b><a href="https://github.com/Cod2rDude">Cod2rDude</a></b></td>
                    <td>Creator</td>
                </tr>
                <tr>
                    <td><b><a href="https://github.com/scrpt2r">scrpt2r</a></b></td>
                    <td>Helped on __log__</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

## [LICENSE](./LICENSE)
This project is licensed under [The MIT License](https://opensource.org/license/mit)

## References

<div align="right">
    <a href="#queues">
        <img src="https://img.shields.io/badge/TOP-↑-blue?style=flat-square" alt="Back to Top">
    </a>
</div>
>>>>>>> 93ffd32 (1.0.0)
