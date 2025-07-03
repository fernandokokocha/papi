export const arrayDifference = (array1, array2) => {
    const set1 = new Set(array1);
    const set2 = new Set(array2);
    return Array.from(set1.difference(set2));
}