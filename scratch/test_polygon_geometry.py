def main():
    # Deck polygon:
    deck_poly = [
        (-25.8, -1.2),
        (-25.8, 0.0),
        (-23.5, 0.0),
        (-10.6, 8.25),
        (10.6, 8.25),
        (23.5, 0.0),
        (25.8, 0.0),
        (25.8, -1.2),
        (17.8, -1.2),
        (17.8, 0.0),
        (10.6, 4.96),
        (-10.6, 4.96),
        (-17.8, 0.0),
        (-17.8, -1.2),
    ]

    # Parapet polygon:
    parapet_poly = [
        (-25.8, -1.2),
        (-25.8, 0.73),
        (-10.6, 10.60),
        (10.6, 10.60),
        (25.8, 0.73),
        (25.8, -1.2),
        (17.8, -1.2),
        (17.8, 0.0),
        (10.6, 4.96),
        (-10.6, 4.96),
        (-17.8, 0.0),
        (-17.8, -1.2),
    ]

    print("Deck polygon points:", len(deck_poly))
    print("Parapet polygon points:", len(parapet_poly))

    # Check for self-intersections using shapely or simple segment check
    def ccw(A,B,C):
        return (C[1]-A[1]) * (B[0]-A[0]) > (B[1]-A[1]) * (C[0]-A[0])
    def intersect(A,B,C,D):
        return ccw(A,C,D) != ccw(B,C,D) and ccw(A,B,C) != ccw(A,B,D)

    for name, poly in [("Deck", deck_poly), ("Parapet", parapet_poly)]:
        n = len(poly)
        has_int = False
        for i in range(n):
            p1, p2 = poly[i], poly[(i+1)%n]
            for j in range(i+2, n):
                if (i == 0 and j == n-1): continue
                p3, p4 = poly[j], poly[(j+1)%n]
                if intersect(p1, p2, p3, p4):
                    print(f"Intersection in {name} between segments {i} and {j}!")
                    has_int = True
        if not has_int:
            print(f"{name} polygon is clean and valid with NO self-intersections!")

if __name__ == "__main__":
    main()
