// //////////////////////////////////////////////////////////
// smallz4.h
// Copyright (c) 2016 Stephan Brumme. All rights reserved.
// see http://create.stephan-brumme.com/smallz4/
//
// "MIT License":
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#pragma once

#include <stdint.h> // uint16_t, uint32_t, ...
#include <cstdlib>  // size_t
#include <vector>


/// LZ4 compression with optimal parsing
/** see smallz4.cpp for a basic I/O interface
    you can easily replace it by a in-memory version
    then all you have to do is:
    #include "smallz4.h"
    smallz4::lz4(GET_BYTES, SEND_BYTES);
**/
class smallz4
{
public:
  // read  several bytes, see getBytesFromIn() in smallz4.cpp for a basic implementation
  typedef size_t (*GET_BYTES) (      void* data, size_t numBytes);
  // write several bytes, see sendBytesToOut() in smallz4.cpp for a basic implementation
  typedef void   (*SEND_BYTES)(const void* data, size_t numBytes);


  /// compress everything in input stream (accessed via getByte) and write to output stream (via send)
  static void lz4(GET_BYTES getBytes, SEND_BYTES sendBytes, unsigned int maxChainLength = MaxChainLength)
  {
    smallz4 obj(maxChainLength);
    obj.compress(getBytes, sendBytes);
  }

  /// version string
  static const char* const getVersion()
  {
    return "1.0";
  }


  // compression level thresholds, made public because I display them in the help screen ...
  enum
  {
    /// greedy mode for short chains (compression level <= 3) instead of optimal parsing / lazy evaluation
    ShortChainsGreedy = 3,
    /// lazy evaluation for medium-sized chains (compression level > 3 and <= 6)
    ShortChainsLazy   = 6
  };

  // ----- END OF PUBLIC INTERFACE -----
private:

  // ----- constants and types -----

  /// a block can be 4 MB
  typedef uint32_t Length;
  /// matches must start within the most recent 64k
  typedef uint16_t Distance;

  enum
  {
    /// each match's length must be >= 4
    MinMatch          =  4,
    /// no matching within the last few bytes
    BlockEndNoMatch   = 12,
    /// last bytes must be literals
    BlockEndLiterals  =  5,

    /// match finder's hash table size (2^HashBits entries, must be less than 32)
    HashBits          = 20,

    /// input buffer size, can be any number but zero ;-)
    BufferSize     = 64*1024,

    /// maximum match distance
    MaxDistance    =   65534,
    /// marker for "no match"
    NoPrevious     = MaxDistance + 1,
    /// stop match finding after MaxChainLength steps (default is unlimited => optimal parsing)
    MaxChainLength = NoPrevious,

    /// refer to location of the previous match (implicit hash chain)
    PreviousSize   = 1 << 16
  };

  /// maximum block size as defined in LZ4 spec
  //const uint32_t MaxBlockSizeArray[] = { 0,0,0,0,64*1024,256*1024,1024*1024,4*1024*1024 };
  /// I only work with the biggest maximum block size (7)
  static const uint32_t MaxBlockSizeId = 7; // header checksum is precalculated only for 7, too
  static const uint32_t MaxBlockSize   = 4*1024*1024;//MaxBlockSizeArray[MaxBlockSizeId];

  //  ----- one and only variable ... -----

  /// how many matches are checked in findLongestMatch
  unsigned int maxChainLength;

  //  ----- code -----

  /// match
  struct Match
  {
    /// true, if long enough
    inline bool isMatch() const
    {
      return length >= MinMatch;
    }

    /// length of match
    Length   length;
    /// start of match
    Distance distance;
  };


  /// create new compressor (only invoked by lz4)
  explicit smallz4(unsigned int newMaxChainLength = MaxChainLength)
  : maxChainLength(newMaxChainLength) // => no limit, but can be changed by setMaxChainLength
  {
  }


  /// return true, if four bytes at a and b match
  inline static bool match4(const void* a, const void* b)
  {
    return *(uint32_t*)a == *(uint32_t*)b;
  }


  /// find longest match of data[pos] between data[begin] and data[end], use match chain stored in previous
  Match findLongestMatch(const unsigned char* data, uint32_t pos, uint32_t begin, uint32_t end, const Distance* previous) const
  {
    Match result;
    result.length = 1;

    // compression level: look only at the first n entries of the match chain
    int32_t stepsLeft = maxChainLength;

    // pointer to position that is matched against everything in data
    const unsigned char* const current = data + pos - begin;
    // don't match beyond this point
    const unsigned char* const stop    = current + end - pos;

    // get distance to previous match, abort if -1 => not existing
    Distance distance = previous[pos % PreviousSize];
    uint32_t totalDistance = 0;
    while (distance != NoPrevious)
    {
      // too far back ?
      totalDistance += distance;
      if (totalDistance > MaxDistance)
        break;

      // prepare next position
      distance = previous[(pos - totalDistance) % PreviousSize];

      // stop searching on lower compression levels
      if (stepsLeft-- <= 0)
        break;

      // let's introduce a new pointer atLeast that points to the first "new" byte of a potential longer match
      const unsigned char* atLeast = current + result.length + 1;

      // the idea is to split the comparison algorithm into 2 phases
      // (1) scan backward from atLeast to current, abort if mismatch
      // (2) scan forward  until a mismatch is found and store length/distance of this new best match
      // current                  atLeast
      //    |                        |
      //    -<<<<<<<< phase 1 <<<<<<<<
      //                              >>> phase 2 >>>

      // impossible to find a longer match because not enough bytes left ?
      if (atLeast > stop)
        break;

      // all bytes between current and atLeast shall be identical, compare 4 bytes at once
      const unsigned char* compare = atLeast - 4;
      bool ok = true;
      while (compare > current)
      {
        // mismatch ?
        if (!match4(compare, compare - totalDistance))
        {
          ok = false;
          break;
        }

        // keep going ...
        compare -= 4;
        // note: - the first four bytes always match
        //       - in the last iteration, compare is either current + 1 or current + 2 or current + 3
        //       - therefore we compare a few bytes twice => but a check to skip these checks is more expensive
      }
      // mismatch ?
      if (!ok)
        continue;

      // we have a new best match, now scan forward from the end
      compare = atLeast;

      // fast loop: check four bytes at once
      while (compare + 4 <= stop && match4(compare,     compare - totalDistance))
        compare += 4;
      // slow loop: check the last 1/2/3 bytes
      while (compare     <  stop &&       *compare == *(compare - totalDistance))
        compare++;

      // store new best match
      result.distance = totalDistance;
      result.length   = compare - current;
    }

    return result;
  }


  /// create shortest output
  /** data points to block's begin; we need it to extract literals **/
  static std::vector<unsigned char> selectBestMatches(const std::vector<Match>& matches, const unsigned char* data)
  {
    // store encoded data
    std::vector<unsigned char> result;
    result.reserve(MaxBlockSize / 2);

    // indices of current literal run
    size_t literalsFrom = 0;
    size_t literalsTo   = 0; // point beyond last literal of the current run

    // walk through the whole block
    for (size_t offset = 0; offset < matches.size(); ) // increment inside of loop
    {
      // get best cost-weighted match
      Match match = matches[offset];

      // if no match, then count literals instead
      if (!match.isMatch())
      {
        // first literal
        if (literalsFrom == literalsTo)
          literalsFrom = literalsTo = offset;

        // one more literal
        literalsTo++;
        // ... and definitely no match
        match.length = 1;
      }

      offset += match.length;
      bool lastToken = (offset == matches.size());
      // continue if simple literal
      if (!match.isMatch() && !lastToken)
        continue;

      // emit token

      // count literals
      size_t numLiterals = literalsTo - literalsFrom;

      // store literals' length
      unsigned char token = (numLiterals < 15) ? (unsigned char)numLiterals : 15;
      token <<= 4;

      // store match length (4 is implied because it's the minimum match length)
      size_t matchLength = match.length - 4;
      if (!lastToken)
        token |= (matchLength < 15) ? matchLength : 15;

      result.push_back(token);

      // >= 15 literals ? (extra bytes to store length)
      if (numLiterals >= 15)
      {
        // 15 is already encoded in token
        numLiterals -= 15;
        // emit 255 until remainder is below 255
        while (numLiterals >= 255)
        {
          result.push_back(255);
          numLiterals -= 255;
        }
        // and the last byte (can be zero, too)
        result.push_back((unsigned char)numLiterals);
      }
      // copy literals
      if (literalsFrom != literalsTo)
      {
        result.insert(result.end(), data + literalsFrom, data + literalsTo);
        literalsFrom = literalsTo = 0;
      }

      // last token doesn't have a match
      if (lastToken)
        break;

      // distance stored in 16 bits / little endian
      result.push_back( match.distance       & 0xFF);
      result.push_back((match.distance >> 8) & 0xFF);

      // >= 15+4 bytes matched (4 is implied because it's the minimum match length)
      if (matchLength >= 15)
      {
        // 15 is already encoded in token
        matchLength -= 15;
        // emit 255 until remainder is below 255
        while (matchLength >= 255)
        {
          result.push_back(255);
          matchLength -= 255;
        }
        // and the last byte (can be zero, too)
        result.push_back((unsigned char)matchLength);
      }
    }

    return result;
  }


  /// walk backwards through all matches and compute number of compressed bytes from current position to the end of the block
  /** note: matches are modified (shortened length) if necessary **/
  static void estimateCosts(std::vector<Match>& matches)
  {
    size_t blockEnd = matches.size();

    typedef uint32_t Cost;
    // minimum cost from this position to the end of the current block
    std::vector<Cost> cost(matches.size(), 0);
    // "cost" represents the number of bytes needed

    // backwards optimal parsing
    size_t posLastMatch = matches.size();
    for (int i = matches.size() - (1 + BlockEndLiterals); i >= 0; i--) // ignore the last 5 bytes, they are always literals
    {
      // watch out for long literal strings that need extra bytes
      Length numLiterals = posLastMatch - i;
      // assume no match
      Cost minCost = cost[i + 1] + 1;
      // an extra byte for every 255 literals required to store length (first 14 bytes are "for free")
      if (numLiterals >= 15 && (numLiterals - 15) % 255 == 0)
        minCost++;

      // if encoded as a literal
      Length bestLength = 1;

      // analyze longest match
      Match match = matches[i];

      // match must not cross block borders
      if (match.isMatch() && i + match.length + BlockEndLiterals > blockEnd)
        match.length = blockEnd - (i + BlockEndLiterals);

      // try all match lengths
      for (Length length = MinMatch; length <= match.length; length++)
      {
        // token (1 byte) + offset (2 bytes)
        Cost currentCost = cost[i + length] + 1 + 2;

        // very long matches need extra bytes for encoding match length
        if (length > 18)
          currentCost += 1 + (length - 18) / 255;

        // better choice ?
        if (currentCost <= minCost)
        {
          // regarding the if-condition:
          // "<"  prefers literals and shorter matches
          // "<=" prefers longer matches
          // they should produce the same number of bytes (because of the same cost)
          // ... but every now and then it doesn't !
          // that's why: too many consecutive literals require an extra length byte
          // (which we took into consideration a few lines above)
          // but we only looked at literals beyond the current position
          // if there are many literal in front of the current position
          // then it may be better to emit a match with the same cost as the literals at the current position
          // => it "breaks" the long chain of literals and removes the extra length byte
          minCost    = currentCost;
          bestLength = length;
          // performance-wise, a long match is usually faster during decoding than multiple short matches
          // on the other hand, literals are faster than short matches as well (assuming same cost)
        }

        // workaround: very long self-referencing matches can slow down the program A LOT
        if (match.distance == 1 && match.length > 18 + 255)
        {
          // assume that longest match is always the best match
          bestLength = match.length;
          minCost    = cost[i + match.length] + 1 + 2 + 1 + (match.length - 18) / 255;
          break;
        }
      }

      // remember position of last match to detect number of consecutive literals
      if (bestLength >= MinMatch)
        posLastMatch = i;

      // store lowest cost so far
      cost[i] = minCost;
      // and adjust best match
      matches[i].length = bestLength;
      if (bestLength == 1)
        matches[i].distance = NoPrevious;
      // note: if bestLength is smaller than the previous matches[i].length then there might be a closer match
      //       which could be more cache-friendly (=> faster decoding)
    }
  }


  /// compress everything in input stream (accessed via getByte) and write to output stream (via send)
  void compress(GET_BYTES getBytes, SEND_BYTES sendBytes) const
  {
    // ==================== write header ====================
    // magic bytes
    const unsigned char magic[4] = { 0x04, 0x22, 0x4D, 0x18 };
    sendBytes(magic, 4);

    // flags
    const unsigned char flags = 1 << 6;
    sendBytes(&flags, 1);
    // max blocksize
    const unsigned char maxBlockSizeId = MaxBlockSizeId << 4;
    sendBytes(&maxBlockSizeId, 1);
    // header checksum (precomputed)
    const unsigned char checksum = 0xDF;
    sendBytes(&checksum, 1);

    // ==================== declarations ====================
    // read the file in chunks/blocks, data will contain only bytes which are relevant for the current block
    std::vector<unsigned char> data;
    // file position corresponding to data[0]
    size_t dataZero = 0;
    // last already read position
    size_t numRead  = 0;

    // passthru data (but still wrap in LZ4 format)
    const bool uncompressed = (maxChainLength == 0);

    // last time we saw a hash
    const uint32_t HashSize = 1 << HashBits;
    std::vector<size_t> lastHash(HashSize, NoPrevious);
    const uint32_t HashMultiplier = 22695477; // taken from https://en.wikipedia.org/wiki/Linear_congruential_generator
    const uint8_t  HashShift = 32 - HashBits;

    // previous position which starts with the same bytes
    std::vector<Distance> previousHash (PreviousSize, Distance(NoPrevious)); // long chains based on my simple hash
    std::vector<Distance> previousExact(PreviousSize, Distance(NoPrevious)); // shorter chains based on exact matching of the first four bytes

    // change buffer size as you like
    std::vector<unsigned char> buffer(BufferSize);

    // first and last offset of a block (next is end-of-block plus 1)
    size_t lastBlock = 0;
    size_t nextBlock = 0;
    while (true)
    {
      // ==================== start new block ====================
      // read more bytes from input
      while (numRead - nextBlock < MaxBlockSize)
      {
        // buffer can be significantly smaller than MaxBLockSize, that's the only reason for this while-block
        size_t incoming = getBytes(&buffer[0], buffer.size());
        if (incoming == 0)
          break;

        numRead += incoming;
        data.insert(data.end(), buffer.begin(), buffer.begin() + incoming);
      }

      // no more data ? => WE'RE DONE !
      if (nextBlock == numRead)
        break;

      // determine block borders
      lastBlock  = nextBlock;
      nextBlock += MaxBlockSize;
      // not beyond end-of-file
      if (nextBlock > numRead)
        nextBlock = numRead;

      size_t blockSize = nextBlock - lastBlock;
      // first byte of the currently processed block (std::vector data may contain the last 64k of the previous block, too)
      const unsigned char* dataBlock = &data[lastBlock - dataZero];

      // ==================== full match finder ====================

      // greedy mode is much faster but produces larger output
      bool isGreedy = (maxChainLength <= ShortChainsGreedy);
      // lazy evaluation: if there is a match, then try running match finder on next position, too, but not after that
      bool isLazy   = !isGreedy && (maxChainLength <= ShortChainsLazy);
      // skip match finding on the next x bytes in greedy mode
      size_t skipMatches = 0;
      // allow match finding on the next byte but skip afterwards (in lazy mode)
      bool   lazyEvaluation = false;

      std::vector<Match> matches(blockSize);
      // find longest matches for each position
      for (size_t i = 0; i < blockSize; i++)
      {
        // no matches at the end of the block (or matching disabled by command-line option -0 )
        if (i + BlockEndNoMatch >= blockSize || uncompressed)
          continue;

        // detect self-matching
        if (i > 0 && dataBlock[i] == dataBlock[i - 1])
        {
          Match prevMatch = matches[i - 1];
          // predecessor had the same match ?
          if (prevMatch.distance == 1 && prevMatch.length > 1024) // TODO: handle very long self-referencing matches
          {
            // just copy predecessor without further (expensive) optimizations
            prevMatch.length--;
            matches[i] = prevMatch;
            continue;
          }
        }

        // read next four bytes
        uint32_t four = *(uint32_t*)(dataBlock + i);
        // convert to a shorter hash
        uint32_t hash = (four * HashMultiplier) >> HashShift;

        // get last occurrence of these bits
        uint32_t last  = lastHash[hash];
        // and store current position
        lastHash[hash] = i + lastBlock;

        // no predecessor or too far away ?
        uint32_t distance = i + lastBlock - last;
        if (last == NoPrevious || distance > MaxDistance)
        {
          previousHash [i % PreviousSize] = NoPrevious;
          previousExact[i % PreviousSize] = NoPrevious;
          continue;
        }

        // build hash chain, i.e. store distance to last match
        previousHash[i % PreviousSize] = distance;

        // skip pseudo-matches (hash collisions) and build a second chain where the first four bytes must match exactly
        while (distance != NoPrevious)
        {
          uint32_t curFour = *(uint32_t*)(&data[last - dataZero]); // may be in the previous block, too
          // actual match found, first 4 bytes are identical
          if (curFour == four)
            break;

          // prevent from accidently hopping on an old, wrong hash chain
          uint32_t curHash = (curFour * HashMultiplier) >> HashShift;
          if (curHash != hash)
          {
            distance = NoPrevious;
            break;
          }

          // try next pseudo-match
          Distance next = previousHash[last % PreviousSize];

          // pointing to outdated hash chain entry ?
          distance += next;
          if (distance > MaxDistance)
          {
            previousHash[last % PreviousSize] = NoPrevious;
            distance = NoPrevious;
            break;
          }

          // closest match is out of range ?
          last -= next;
          if (next == NoPrevious || last < dataZero)
          {
            distance = NoPrevious;
            break;
          }
        }

        // no match at all ?
        if (distance == NoPrevious)
        {
          previousExact[i % PreviousSize] = NoPrevious;
          continue;
        }

        // store distance to previous match
        previousExact[i % PreviousSize] = distance;

        // TODO: long consecutive literals
        /*if (distance == 1 && i > 0)
        {
          if (matches[i - 1].length > MinMatch)
          {
            matches[i] = matches[i - 1];
            //continue;
          }
        }*/

        // skip match finding if in greedy mode
        if (skipMatches > 0)
        {
          skipMatches--;
          if (!lazyEvaluation)
            continue;
          lazyEvaluation = false;
        }

        // and look for longest match
        Match longest = findLongestMatch(&data[0], i + lastBlock, dataZero, nextBlock - BlockEndLiterals, &previousExact[0]);
        matches[i] = longest;

        // no match finding needed for the next few bytes in greedy/lazy mode
        if (longest.isMatch() && (isLazy || isGreedy))
        {
          lazyEvaluation = (skipMatches == 0);
          skipMatches = longest.length;
        }
      }

      // ==================== estimate costs (number of compressed bytes) ====================

      // not needed in greedy mode and/or very short blocks
      if (matches.size() > BlockEndNoMatch && maxChainLength > ShortChainsGreedy)
        estimateCosts(matches);

      // ==================== select best matches ====================

      std::vector<unsigned char> block;
      if (!uncompressed)
        block = selectBestMatches(matches, &data[lastBlock - dataZero]);

      // ==================== output ====================

      // automatically decide whether compressed or uncompressed
      size_t uncompressedSize = nextBlock - lastBlock;
      // did compression do harm ?
      bool useCompression = block.size() < uncompressedSize && !uncompressed;

      // block size
      uint32_t numBytes = useCompression ? block.size() : uncompressedSize;
      uint32_t numBytesTagged = numBytes | (useCompression ? 0 : 0x80000000);
      unsigned char num1 =  numBytesTagged         & 0xFF; sendBytes(&num1, 1);
      unsigned char num2 = (numBytesTagged >>  8)  & 0xFF; sendBytes(&num2, 1);
      unsigned char num3 = (numBytesTagged >> 16)  & 0xFF; sendBytes(&num3, 1);
      unsigned char num4 = (numBytesTagged >> 24)  & 0x7F; sendBytes(&num4, 1);

      if (useCompression)
        sendBytes(&block[0], numBytes);
      else // uncompressed ? => copy input data
        sendBytes(&data[lastBlock - dataZero], numBytes);

      // remove already processed data except for the last 64kb which could be used for intra-block matches
      if (data.size() > MaxDistance)
      {
        size_t remove = data.size() - MaxDistance;
        dataZero += remove;
        data.erase(data.begin(), data.begin() + remove);
      }
    }

    // add an empty block
    uint32_t zero = 0;
    sendBytes(&zero, 4);
  }
};
