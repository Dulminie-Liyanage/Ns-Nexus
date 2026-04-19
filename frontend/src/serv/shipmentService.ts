import API from "../src/api/axios";

// GET all shipments
export const getShipments = async () => {
  const response = await API.get("/shipments");
  return response.data;
};

// CREATE shipment (for later)
/*export const createShipment = async (data: any) => {
  const response = await API.post("/shipments", data);
  return response.data;
};*/

// UPDATE shipment
export const updateShipment = async (id: number, status: string) => {
  const res = await API.put(`/shipments/${id}`, {
    status,
  });
  return res.data;
};;