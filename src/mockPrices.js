export default function mockPrices(barcode) {
  return [
    {
      store: 'Amazon',
      price: 12.99,
      image: 'https://via.placeholder.com/60'
    },
    {
      store: 'Walmart',
      price: 13.49,
      image: 'https://via.placeholder.com/60'
    },
    {
      store: 'Target',
      price: 14.29,
      image: 'https://via.placeholder.com/60'
    }
  ].sort((a, b) => a.price - b.price);
}
