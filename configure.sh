#!/bin/bash

install_opam() {
    # Check if OPAM is already installed
    if command -v opam &> /dev/null; then
        echo "OPAM is already installed."
        return 0
    fi

    # Check which package manager is available
    if command -v apt-get &> /dev/null; then
        echo "Installing OPAM using APT..."
        sudo apt-get update
        sudo apt-get install -y opam
    elif command -v yum &> /dev/null; then
        echo "Installing OPAM using Yum..."
        sudo yum install -y opam
    elif command -v brew &> /dev/null; then
        echo "Installing OPAM using Homebrew..."
        brew install opam
    else
        echo "No supported package manager found. Install OPAM manualy."
        return 1
    fi

    echo "OPAM installation complete."
    return 0
}

check_and_install_packages() {
    # Check if ctypes package is installed
    if opam list | grep -q "ctypes"; then
        echo "ctypes package is already installed."
    else
        echo "ctypes package is not installed. Installing it..."
        if opam install ctypes; then
            echo "ctypes package installed successfully."
        else
            echo "Failed to install ctypes package."
            return 1
        fi
    fi
    
    # Check if ctypes-foreign package is installed
    if opam list | grep -q "ctypes-foreign"; then
        echo "ctypes-foreign package is already installed."
    else
        echo "ctypes-foreign package is not installed. Installing it..."
        if opam install ctypes-foreign; then
            echo "ctypes-foreign package installed successfully."
        else
            echo "Failed to install ctypes-foreign package."
            return 1
        fi
    fi
    
    return 0
}

install_opam
if [ $? -eq 0 ]; then
    echo "OPAM installation successful."
else
    echo "OPAM installation failed."
    exit 1
fi

check_and_install_packages
if [$? -eq 0 ]; then
    echo "Ocaml PACKAGES are installed successfully"
else
    echo "Ocaml PACKAGE's installation failed."
    exit 1
fi
exit 0
