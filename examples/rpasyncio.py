# [[file:rpasyncio.org::*Python module header][Python module header:1]]
"""Examples stolen from 'https://realpython.com'."""
# Python module header:1 ends here


# [[file:rpasyncio.org::rp1][rp1]]
def rp1():
    """Show 'countsync.py' example."""
    import asyncio
    import time

    async def count():
        print("One")
        await asyncio.sleep(1)
        print("Two")

    async def main():
        await asyncio.gather(count(), count(), count())

    tick = time.perf_counter()
    asyncio.run(main())
    ticktock = time.perf_counter() - tick
    print(f"{__name__} executed in {ticktock:0.2f} seconds.")


# rp1 ends here


# [[file:rpasyncio.org::rp2][rp2]]
def rp2(seed):
    """Show 'rand.py' example."""
    import asyncio
    import random

    # ANSI colors
    c = (
        "\033[0m",  # End of color
        "\033[36m",  # Cyan
        "\033[91m",  # Red
        "\033[35m",  # Magenta
    )

    async def makerandom(idx: int, threshold: int = 6) -> int:
        print(c[idx + 1] + f"Initiated makerandom({idx}).")
        i = random.randint(0, 10)
        while i <= threshold:
            print(c[idx + 1] + f"makerandom({idx}) == {i} too low; retrying.")
            await asyncio.sleep(idx + 1)
            i = random.randint(0, 10)
        print(c[idx + 1] + f"---> Finished: makerandom({idx}) == {i}" + c[0])
        return i

    async def main():
        res = await asyncio.gather(*(makerandom(i, 10 - i - 1) for i in range(3)))
        return res

    random.seed(seed)
    r1, r2, r3 = asyncio.run(main())
    print()
    print(f"r1: {r1}, r2: {r2}, r3: {r3}")


# rp2 ends here


# [[file:rpasyncio.org::rp3][rp3]]
def rp3(seed, args=None):
    """Show 'chained.py' example."""
    import asyncio
    import random
    import time

    async def part1(n: int) -> str:
        i = random.randint(0, 10)
        print(f"part1({n}) sleeping for {i} seconds.")
        await asyncio.sleep(i)
        result = f"result{n}-1"
        print(f"Returning part1({n}) == {result}.")
        return result

    async def part2(n: int, arg: str) -> str:
        i = random.randint(0, 10)
        print(f"part2({n, arg}) sleeping for {i} seconds.")
        await asyncio.sleep(i)
        result = f"result{n}-2 derived from {arg}"
        print(f"Returning part2{n, arg} == {result}.")
        return result

    async def chain(n: int) -> None:
        start = time.perf_counter()
        p1 = await part1(n)
        p2 = await part2(n, p1)
        end = time.perf_counter() - start
        print(f"--> Chained result{n} => {p2} (took {end:0.2f} seconds).")

    async def main(*args):
        await asyncio.gather(*(chain(n) for n in args))

    random.seed(seed)
    args = [1, 2, 3] if args is None else args
    start = time.perf_counter()
    asyncio.run(main(*args))
    end = time.perf_counter() - start
    print(f"Program finished in {end:0.2f} seconds.")


# rp3 ends here
