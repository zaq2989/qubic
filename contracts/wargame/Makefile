# SPDX-License-Identifier: MIT

CXX = g++
CXXFLAGS = -std=c++17 -Wall -Wextra -O2 -fPIC
LDFLAGS = -shared

TARGET = wargame_contract.so
SOURCES = wargame_contract.cpp
OBJECTS = $(SOURCES:.cpp=.o)

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(LDFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET)

test: $(TARGET)
	$(CXX) -std=c++17 -Wall test_contract.cpp -o test_contract
	./test_contract

.PHONY: all clean test